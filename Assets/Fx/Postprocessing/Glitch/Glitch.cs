using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Aras.PostProcessing
{
    [System.Serializable]
    [PostProcess(typeof(GlitchRenderer), PostProcessEvent.AfterStack, "Aras/Glitch")]
    public sealed class Glitch : PostProcessEffectSettings
    {
        [Range(0, 1)] public FloatParameter intensity = new FloatParameter { value = 0 };
        [Range(0, 1)] public FloatParameter glitching = new FloatParameter { value = 1 };
        [Range(0, 1)] public FloatParameter discolor = new FloatParameter { value = 1 };
        [Range(0, 1)] public FloatParameter interleave = new FloatParameter { value = 1 };
    }

    sealed class GlitchRenderer : PostProcessEffectRenderer<Glitch>
    {
        static class ShaderIDs
        {
            internal static readonly int Params = Shader.PropertyToID("_Params");
        }

        public override void Render(PostProcessRenderContext context)
        {
            var cmd = context.command;
            cmd.BeginSample("Glitch");

            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Aras/PostProcessing/Glitch"));
            sheet.properties.SetVector(ShaderIDs.Params, new Vector4(settings.intensity, settings.glitching, settings.discolor, settings.interleave));
            cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

            cmd.EndSample("Glitch");
        }
    }
}
