using UnityEditor;
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
            if (Cursor.visible)
                Cursor.visible = false;
            if (Input.GetKeyDown(KeyCode.O))
                _director.time = _director.time - delta;
            if (Input.GetKeyDown(KeyCode.P))
                _director.time = _director.time + delta;
            if (Input.GetKeyDown(KeyCode.Escape) || _director.time >= 264)
            {
                #if UNITY_EDITOR
                EditorApplication.isPlaying = false;
                #else
                Application.Quit();
                #endif
            }
        }
        Shader.SetGlobalVector("_TimelineTime", new Vector4((float)_director.time, 0,0,0));
	}
}
