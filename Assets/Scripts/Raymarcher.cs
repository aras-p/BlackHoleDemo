﻿using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;

[ExecuteInEditMode]
public class Raymarcher : MonoBehaviour
{
    public Material m_Material;
	public Vector4 m_Param1;
	public Vector4 m_Param2;

    CommandBuffer m_CB;
    HashSet<Camera> m_Cameras = new HashSet<Camera>();

    void OnEnable()
    {
    	Camera.onPreRender += MyPreRender;
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
    }

    public void MyPreRender(Camera cam)
    {
    	if (m_Material == null)
    		return;

    	if (cam.cameraType != CameraType.Game && cam.cameraType != CameraType.SceneView)
    		return;

        if (m_CB==null)
        {
            m_CB = new CommandBuffer();
            m_CB.name = "Raymarch";
            m_CB.DrawMesh(RuntimeUtilities.fullscreenTriangle, Matrix4x4.identity, m_Material, 0, 0);
        }

        if (!m_Cameras.Contains(cam))
        {
            cam.AddCommandBuffer(CameraEvent.AfterGBuffer, m_CB);
            m_Cameras.Add(cam);
        }
    }

    public void Update()
    {
    	Shader.SetGlobalMatrix("_RaymarchTransform", transform.localToWorldMatrix);
	    Shader.SetGlobalMatrix("_RaymarchInverseTransform", transform.worldToLocalMatrix);
	    if (m_Material != null)
	    {
		    m_Material.SetVector("_Param1", m_Param1);
		    m_Material.SetVector("_Param2", m_Param2);
	    }
    }
}
