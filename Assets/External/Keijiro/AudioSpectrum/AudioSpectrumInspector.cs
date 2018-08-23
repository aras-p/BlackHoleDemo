// Audio spectrum component
// By Keijiro Takahashi, 2013
// https://github.com/keijiro/unity-audio-spectrum
using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(AudioSpectrum))]
public class AudioSpectrumInspector : Editor
{
    static string[] sampleOptionStrings = {
        "256", "512", "1024", "2048", "4096"
    };
    static int[] sampleOptions = {
        256, 512, 1024, 2048, 4096
    };
    static string[] bandOptionStrings = {
        "4 band", "4 band (visual)", "8 band", "10 band (ISO standard)", "26 band", "31 band (FBQ3102)"
    };
    static int[] bandOptions = {
        (int)AudioSpectrum.BandType.FourBand,
        (int)AudioSpectrum.BandType.FourBandVisual,
        (int)AudioSpectrum.BandType.EightBand,
        (int)AudioSpectrum.BandType.TenBand,
        (int)AudioSpectrum.BandType.TwentySixBand,
        (int)AudioSpectrum.BandType.ThirtyOneBand
    };

    Material material;
    void OnEnable()
    {
        material = new Material(Shader.Find("Hidden/Internal-Colored"));
    }

    public override void OnInspectorGUI ()
    {
        var spectrum = target as AudioSpectrum;

        // Component properties.
        spectrum.numberOfSamples = EditorGUILayout.IntPopup ("Number of samples", spectrum.numberOfSamples, sampleOptionStrings, sampleOptions);
        spectrum.bandType = (AudioSpectrum.BandType)EditorGUILayout.IntPopup ("Band type", (int)spectrum.bandType, bandOptionStrings, bandOptions);
        spectrum.fallSpeed = EditorGUILayout.Slider ("Fall speed", spectrum.fallSpeed, 0.01f, 0.5f);
        spectrum.sensibility = EditorGUILayout.Slider ("Sensibility", spectrum.sensibility, 1.0f, 20.0f);

        // Shows the spectrum curve.
        Rect position = GUILayoutUtility.GetRect(10, 10000, 200, 200);
        if (Event.current.type == EventType.Repaint)
        {
            GUI.BeginClip(position);
            material.SetPass(0);

            var levels = spectrum.Levels;
            var means = spectrum.MeanLevels;
            var peaks = spectrum.PeakLevels;

            var width = position.width;
            var height = position.height;
            var step = position.width / levels.Length;

            GL.Begin(GL.LINES);
            for (var i = 0; i < levels.Length; i++)
            {
                GL.Color(Color.green * new Color(1, 1, 1, 0.5f));
                GL.Vertex3(i * step, levels[i] * height, 0);
                GL.Vertex3((i+1) * step, levels[i] * height, 0);

                GL.Color(Color.blue * new Color(1, 1, 1, 0.5f));
                GL.Vertex3(i * step, means[i] * height, 0);
                GL.Vertex3((i + 1) * step, means[i] * height, 0);

                GL.Color(Color.red * new Color(1, 1, 1, 0.5f));
                GL.Vertex3(i * step, peaks[i] * height, 0);
                GL.Vertex3((i + 1) * step, peaks[i] * height, 0);

                var ratio = levels[i] / (peaks[i]+0.01f);
                GL.Color(Color.black * new Color(1,1,1,0.2f));
                GL.Vertex3(i * step, ratio * height, 0);
                GL.Vertex3((i + 1) * step, ratio * height, 0);
            }
            GL.End();

            GUI.EndClip();
        }

        // Update frequently while it's playing.
        if (EditorApplication.isPlaying) {
            EditorUtility.SetDirty (target);
        }
    }
}