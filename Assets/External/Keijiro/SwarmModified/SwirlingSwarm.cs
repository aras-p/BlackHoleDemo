// Swarm - Special renderer that draws a swarm of swirling/crawling lines.
// Modified version from original over at https://github.com/keijiro/Swarm

using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Swarm
{
    [ExecuteInEditMode]
    public sealed class SwirlingSwarm : MonoBehaviour
    {        
        [SerializeField] int _instanceCount = 1000;

        public int instanceCount {
            get { return _instanceCount; }
        }

        [SerializeField] TubeTemplate _template;

        public TubeTemplate template {
            get { return _template; }
        }

        [SerializeField] float _radius = 0.005f;

        public float radius {
            get { return _radius; }
            set { _radius = value; }
        }

        [SerializeField] float _length = 1;

        public float length {
            get { return _length; }
            set { _length = value; }
        }

        [SerializeField] float _spread = 1;

        public float spread {
            get { return _spread; }
            set { _spread = value; }
        }

        [SerializeField] float _noiseFrequency = 0.5f;

        public float noiseFrequency {
            get { return _noiseFrequency; }
            set { _noiseFrequency = value; }
        }

        [SerializeField] Vector3 _noiseMotion = Vector3.up * 0.1f;

        public Vector3 noiseMotion {
            get { return _noiseMotion; }
            set { _noiseMotion = value; }
        }

        [SerializeField]  float _time = 0.0f;

        [SerializeField] Material _material;

        public Material material {
            get { return _material; }
        }

        [SerializeField] int _randomSeed;

        public int randomSeed {
            set { _randomSeed = value; }
        }

        [SerializeField, HideInInspector] ComputeShader _compute;

        ComputeBuffer _drawArgsBuffer;
        ComputeBuffer _positionBuffer;
        ComputeBuffer _tangentBuffer;
        ComputeBuffer _normalBuffer;
        MaterialPropertyBlock _props;
        Vector3 _noiseOffset;

        const int kThreadCount = 64;
        int ThreadGroupCount { get { return _instanceCount / kThreadCount; } }
        int InstanceCount { get { return kThreadCount * ThreadGroupCount; } }
        int HistoryLength { get { return _template.segments + 1; } }
        
        CommandBuffer m_CB;
        HashSet<Camera> m_Cameras = new HashSet<Camera>();
        
        void OnEnable()
        {
            Camera.onPreRender += MyPreRender;
            Initialize();
        }

        void OnDisable()
        {            
            Camera.onPreRender -= MyPreRender;
            if (m_CB != null)
            {
                foreach (var cam in m_Cameras)
                {
                    if (cam != null)
                        cam.RemoveCommandBuffer(CameraEvent.AfterGBuffer, m_CB);
                }
                m_Cameras.Clear();
            }
            m_CB = null;
            
            if (_drawArgsBuffer != null) _drawArgsBuffer.Release();
            if (_positionBuffer != null) _positionBuffer.Release();
            if (_tangentBuffer != null) _tangentBuffer.Release();
            if (_normalBuffer != null) _normalBuffer.Release();
            //if (_materialCloned) DestroyImmediate(_material);
            //_materialCloned = false;
        }
        
        public void MyPreRender(Camera cam)
        {
            if (_material == null || _template == null || _template.mesh == null || _drawArgsBuffer == null || _props == null)
                return;

            if (cam.cameraType != CameraType.Game && cam.cameraType != CameraType.SceneView)
                return;

            if (m_CB==null)
            {
                m_CB = new CommandBuffer();
                m_CB.name = "Swirl";
                m_CB.DrawMeshInstancedIndirect(_template.mesh, 0, _material, 0, _drawArgsBuffer, 0, _props);
            }

            if (!m_Cameras.Contains(cam))
            {
                cam.AddCommandBuffer(CameraEvent.AfterGBuffer, m_CB);
                m_Cameras.Add(cam);
            }
        }
        

        void OnValidate()
        {
            _instanceCount = Mathf.Max(kThreadCount, _instanceCount);
            _radius = Mathf.Max(0, _radius);
            _length = Mathf.Max(0, _length);
            _spread = Mathf.Max(0, _spread);
            _noiseFrequency = Mathf.Max(0, _noiseFrequency);
        }

        void Initialize()
        {
            // Initialize the indirect draw args buffer.
            _drawArgsBuffer = new ComputeBuffer(
                1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments
            );

            _drawArgsBuffer.SetData(new uint[5] {
                _template.mesh.GetIndexCount(0), (uint)InstanceCount, 0, 0, 0
            });

            // Allocate compute buffers.
            _positionBuffer = new ComputeBuffer(HistoryLength * InstanceCount, 16);
            _tangentBuffer = new ComputeBuffer(HistoryLength * InstanceCount, 16);
            _normalBuffer = new ComputeBuffer(HistoryLength * InstanceCount, 16);

            // This property block is used only for avoiding an instancing bug.
            _props = new MaterialPropertyBlock();

            _noiseOffset = Vector3.one * _randomSeed;
        }

        void Update()
        {
            if (_compute == null || _material == null)
                return;
            // Invoke the update compute kernel.
            var kernel = _compute.FindKernel("SwirlingUpdate");

            _compute.SetInt("InstanceCount", InstanceCount);
            _compute.SetInt("HistoryLength", HistoryLength);
            _compute.SetFloat("RandomSeed", _randomSeed);
            _compute.SetFloat("Spread", _spread);
            _compute.SetFloat("StepWidth", _length / _template.segments);
            _compute.SetFloat("NoiseFrequency", _noiseFrequency);
            _compute.SetVector("NoiseOffset", _noiseOffset);

            _compute.SetBuffer(kernel, "PositionBuffer", _positionBuffer);

            _compute.Dispatch(kernel, ThreadGroupCount, 1, 1);

            // Invoke the reconstruction kernel.
            kernel = _compute.FindKernel("SwirlingReconstruct");

            _compute.SetBuffer(kernel, "PositionBufferRO", _positionBuffer);
            _compute.SetBuffer(kernel, "TangentBuffer", _tangentBuffer);
            _compute.SetBuffer(kernel, "NormalBuffer", _normalBuffer);

            _compute.Dispatch(kernel, ThreadGroupCount, 1, 1);

            // Draw the mesh with instancing.
            _props.Clear();
            _props.SetFloat("_UniqueID", Random.value);
            _props.SetFloat("_Radius", _radius);
            
            _props.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);
            _props.SetMatrix("_WorldToLocal", transform.worldToLocalMatrix);

            _props.SetBuffer("_PositionBuffer", _positionBuffer);
            _props.SetBuffer("_TangentBuffer", _tangentBuffer);
            _props.SetBuffer("_NormalBuffer", _normalBuffer);

            _props.SetInt("_InstanceCount", InstanceCount);
            _props.SetInt("_HistoryLength", HistoryLength);
            _props.SetInt("_IndexLimit", HistoryLength);

            // Move the noise field.
            //_noiseOffset += _noiseMotion * Time.deltaTime;
            _noiseOffset = _noiseMotion * _time;
        }
    }
}
