using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class PointSwarm : MonoBehaviour
{
	public Mesh m_Mesh;
	public int m_PointsX = 20;
	public int m_PointsY = 20;
	public int m_PointsZ = 20;
	public Bounds m_Bounds = new Bounds(Vector3.zero, Vector3.one * 10.0f);
	public float m_NoiseFrequency = 0.5f;
	public Vector3 m_NoiseMotion = new Vector3(0,0.1f,0);
	public float m_Speed = 1.0f;
	public float m_Time;
	public int m_RandomSeed = 1234;

	public Texture2D m_Texture;
	public Material m_Material;
	[HideInInspector] public ComputeShader m_ComputeShader;

	ComputeBuffer m_DrawArgsBuffer;
	ComputeBuffer m_PointBuffer;
	int m_PrevPointCount = -1;
	MaterialPropertyBlock m_Props;

	public void OnEnable()
	{
		Initialize();
	}
	public void OnDisable()
	{
		if (m_DrawArgsBuffer != null) m_DrawArgsBuffer.Release();
		if (m_PointBuffer != null) m_PointBuffer.Release();
	}

	void Initialize()
	{
		var totalPoints = m_PointsX * m_PointsY * m_PointsZ;
		
		m_DrawArgsBuffer = new ComputeBuffer(
			1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments
		);
		
		m_PointBuffer = new ComputeBuffer(totalPoints, 12+12);
		m_PrevPointCount = totalPoints;
		
		var kernel = m_ComputeShader.FindKernel("SwarmInitialize");
		m_ComputeShader.SetBuffer(kernel, "PointBuffer", m_PointBuffer);
		m_ComputeShader.SetInt("PointsX", m_PointsX);
		m_ComputeShader.SetInt("PointsY", m_PointsY);
		m_ComputeShader.SetInt("PointsZ", m_PointsZ);
		m_ComputeShader.SetVector("BoundsMin", m_Bounds.min);
		m_ComputeShader.SetVector("BoundsMax", m_Bounds.max);
		m_ComputeShader.SetVector("NoiseOffset", m_NoiseMotion); //@TODO
		m_ComputeShader.SetFloat("NoiseFrequency", m_NoiseFrequency);
		m_ComputeShader.SetTexture(kernel, "ProjTexture", m_Texture);
		m_ComputeShader.Dispatch(kernel, m_PointsX, m_PointsY, m_PointsZ);
		
		m_Props = new MaterialPropertyBlock();
	}

	public void Update()
	{
		if (m_ComputeShader == null || m_Material == null)
			return;
		
		if (m_PrevPointCount != m_PointsX * m_PointsY * m_PointsZ)
		{
			OnDisable();
			OnEnable();
		}

		// update the point cloud
		var kernel = m_ComputeShader.FindKernel("SwarmUpdate");
		m_ComputeShader.SetBuffer(kernel, "PointBuffer", m_PointBuffer);
		m_ComputeShader.SetFloat("StepWidth", m_Speed * Time.deltaTime);
		m_ComputeShader.Dispatch(kernel, m_PointsX, m_PointsY, m_PointsZ);
		
		m_DrawArgsBuffer.SetData(new uint[] {
			m_Mesh.GetIndexCount(0),
			(uint)(m_PointsX * m_PointsY * m_PointsZ),
			0,
			0,
			0
		});
		
		// draw the points as instanced meshes
		m_Props.Clear();
		//m_Props.SetFloat("_UniqueID", Random.value);
		//m_Props.SetFloat("_Radius", _radius);
            
		m_Props.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);
		m_Props.SetMatrix("_WorldToLocal", transform.worldToLocalMatrix);

		m_Props.SetBuffer("PointBuffer", m_PointBuffer);

		//m_Props.SetInt("_InstanceCount", InstanceCount);
		//m_Props.SetInt("_HistoryLength", HistoryLength);
		//m_Props.SetInt("_IndexLimit", HistoryLength);
        
		Graphics.DrawMeshInstancedIndirect(m_Mesh, 0, m_Material,
			m_Bounds,
			m_DrawArgsBuffer, 0,
			m_Props, ShadowCastingMode.On, true);		
	}

	void OnDrawGizmosSelected()
	{
		Gizmos.color = Color.cyan;
		Gizmos.matrix = transform.localToWorldMatrix;
		Gizmos.DrawWireCube(m_Bounds.center, m_Bounds.size);
		if (m_Texture != null)
		{
			//Gizmos.DrawGUITexture(new Rect(0,0,20,20), m_Texture);
		}
	}
}
