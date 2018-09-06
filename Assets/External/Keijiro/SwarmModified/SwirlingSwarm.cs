// Swarm - Special renderer that draws a swarm of swirling/crawling lines.
// Modified version from original over at https://github.com/keijiro/Swarm

using UnityEngine;
using UnityEngine.Rendering;

namespace Swarm
{
    [ExecuteInEditMode]
    public sealed class SwirlingSwarm : MonoBehaviour
    {        
        [Range(0,10000)][SerializeField] int _instanceCount = 1000;
        [Range(0.0f,1.0f)][SerializeField] float _drawAmount = 1.0f;

        [SerializeField] TubeTemplate _template;

        [Range(0.0f,0.05f)][SerializeField] float _radius = 0.005f;

        [SerializeField] float _length = 1;

        [SerializeField] float _spread = 1;

        [SerializeField] float _noiseFrequency = 0.5f;

        [SerializeField] Vector3 _noiseMotion = Vector3.up * 0.1f;

        [SerializeField]  float _time;

        [SerializeField] Material _material;

        [SerializeField] int _randomSeed;

        [SerializeField, HideInInspector] ComputeShader _compute;

        ComputeBuffer _drawArgsBuffer;
        ComputeBuffer _positionBuffer;
        ComputeBuffer _tangentBuffer;
        ComputeBuffer _normalBuffer;
        MaterialPropertyBlock _props;
        Vector3 _noiseOffset;
        int _prevInstanceCount = -1;

        const int kThreadCount = 64;
        int ThreadGroupCount => _instanceCount / kThreadCount;
        int InstanceCount => kThreadCount * ThreadGroupCount;
        int HistoryLength => _template.segments + 1;

        void OnEnable()
        {
            Initialize();
        }

        void OnDisable()
        {            
            if (_drawArgsBuffer != null) _drawArgsBuffer.Release();
            if (_positionBuffer != null) _positionBuffer.Release();
            if (_tangentBuffer != null) _tangentBuffer.Release();
            if (_normalBuffer != null) _normalBuffer.Release();
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

            if (_prevInstanceCount != _instanceCount)
            {
                OnDisable();
                OnEnable();
                _prevInstanceCount = _instanceCount;
            }
            
            _drawArgsBuffer.SetData(new uint[] {
                _template.mesh.GetIndexCount(0),
                (uint)(InstanceCount * _drawAmount),
                0,
                0,
                0
            });
            
            // Invoke the update compute kernel.
            _noiseOffset = _noiseMotion * _time;
            
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
            
            Graphics.DrawMeshInstancedIndirect(_template.mesh, 0, _material, new Bounds(transform.position, new Vector3(20,20,20)), _drawArgsBuffer, 0, _props, ShadowCastingMode.On, true);
        }
    }
}
