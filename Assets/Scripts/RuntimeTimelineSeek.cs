using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

[ExecuteInEditMode]
public class RuntimeTimelineSeek : MonoBehaviour
{
    public float delta = 5.0f;
    PlayableDirector _director;

	void Start ()
    {
        _director = GetComponent<PlayableDirector>();
	}
	
	void Update ()
    {
        if (Application.isPlaying)
        {
            if (Input.GetKeyDown(KeyCode.O))
                _director.time = _director.time - delta;
            if (Input.GetKeyDown(KeyCode.P))
                _director.time = _director.time + delta;
        }
        Shader.SetGlobalVector("_TimelineTime", new Vector4((float)_director.time, 0,0,0));
	}
}
