// Custom timeline track for procedural motion
// https://github.com/keijiro/ProceduralMotionTrack

using UnityEditor;
using UnityEngine;
using UnityEngine.Playables;

namespace Klak.Timeline
{
    [CustomEditor(typeof(ConstantMotion)), CanEditMultipleObjects]
    class ConstantMotionEditor : Editor
    {
        SerializedProperty _position;
        SerializedProperty _rotation;
        SerializedProperty _positionDelta;
        SerializedProperty _rotationDelta;

        void OnEnable()
        {
            _position = serializedObject.FindProperty("template.position");
            _rotation = serializedObject.FindProperty("template.rotation");
            _positionDelta = serializedObject.FindProperty("template.positionDelta");
            _rotationDelta = serializedObject.FindProperty("template.rotationDelta");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.PropertyField(_position);
            EditorGUILayout.PropertyField(_rotation);
            EditorGUILayout.PropertyField(_positionDelta);
            EditorGUILayout.PropertyField(_rotationDelta);

            serializedObject.ApplyModifiedProperties();
        }
    }
}
