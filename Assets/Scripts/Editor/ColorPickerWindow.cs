using UnityEditor;
using UnityEngine;

public class ColorPickerWindow : EditorWindow
{
	Color color = Color.white;

	[MenuItem("Tools/Color Picker")]
	public static void Init ()
	{
		var window = GetWindow<ColorPickerWindow>("Color Picker");
		window.Show();
	}

	protected virtual void OnGUI ()
	{
		color = EditorGUILayout.ColorField("Color", color);
		EditorGUILayout.TextField("sRGB", $"half4({color.r:f3}, {color.g:f3}, {color.b:f3}, {color.a:f3})");
		EditorGUILayout.TextField("Linear", $"half4({Mathf.GammaToLinearSpace(color.r):f3}, {Mathf.GammaToLinearSpace(color.g):f3}, {Mathf.GammaToLinearSpace(color.b):f3}, {color.a:f3})");
	}	
}
