using UnityEditor;
using UnityEngine;

public class ScaleFromTextureAspect
{
	[MenuItem("Tools/Scale From Texture Aspect")]
	static void ScaleFromTexture()
	{
		var tr = Selection.activeGameObject.transform;
		var tex = GetTextureFromSelection();
		var scale = tr.localScale;
		scale.x = scale.y * tex.width / tex.height;
		tr.localScale = scale;
	}

	[MenuItem("Tools/Scale From Texture Aspect", true)]
	static bool ValidateScaleFromTexture()
	{
		return GetTextureFromSelection() != null;
	}

	static Texture GetTextureFromSelection()
	{
		var go = Selection.activeGameObject;
		if (go == null)
			return null;
		var renderer = go.GetComponent<Renderer>();
		if (renderer == null)
			return null;
		var mat = renderer.sharedMaterial;
		if (mat == null)
			return null;
		return mat.mainTexture;
	}
}
