Shader "Demo/Raymarcher"
{
	Properties
	{
		_Color ("Diffuse", Color) = (0.3,0.3,0.3,1.0)
		_SpecColor ("Specular", Color) = (0.2,0.2,0.2,1.0)
		_Smoothness ("Smoothness", Range(0,1)) = 0.5
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Cull Off
			Name "DEFERRED"
	        Stencil
	        {
	            Comp Always
	            Pass Replace
	            //Ref [_StencilNonBackground] // problematic
	            Ref 128
	        }

CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "Raymarching.cginc"

float kaleidoscopic_IFS(float3 z)
{
    int FRACT_ITER      = 20;
    float FRACT_SCALE   = 1.8;
    float FRACT_OFFSET  = 1.0;

    float c = 2.0;
    z.y = modc(z.y, c)-c/2.0;
    z = rotateZ(z, PI/2.0);
    float r;
    int n1 = 0;
    for (int n = 0; n < FRACT_ITER; n++) {
        float rotate = PI*0.5;
        z = rotateX(z, rotate);
        z = rotateY(z, rotate);
        z = rotateZ(z, rotate);

        z.xy = abs(z.xy);
        if (z.x+z.y<0.0) z.xy = -z.yx; // fold 1
        if (z.x+z.z<0.0) z.xz = -z.zx; // fold 2
        if (z.y+z.z<0.0) z.zy = -z.yz; // fold 3
        z = z*FRACT_SCALE - FRACT_OFFSET*(FRACT_SCALE-1.0);
    }
    return (length(z) ) * pow(FRACT_SCALE, -float(FRACT_ITER));
}


float tglad_formula(float3 z0)
{
    z0 = modc(z0, 2.0);

    float mr=0.25, mxr=1.0;
    float4 scale=float4(-3.12,-3.12,-3.12,3.12), p0=float4(0.0,1.59,-1.0,0.0);
    float4 z = float4(z0,1.0);
    for (int n = 0; n < 3; n++) {
        z.xyz=clamp(z.xyz, -0.94, 0.94)*2.0-z.xyz;
        z*=scale/clamp(dot(z.xyz,z.xyz),mr,mxr);
        z+=p0;
    }
    float dS=(length(max(abs(z.xyz)-float3(1.2,49.0,1.4),0.0))-0.06)/z.w;
    return dS;
}


// distance function from Hartverdrahtet
// ( http://www.pouet.net/prod.php?which=59086 )
float hartverdrahtet(float3 f)
{
    float3 cs=float3(.808,.808,1.167);
    float fs=1.;
    float3 fc=0;
    float fu=10.;
    float fd=.763;
    
    // scene selection
    {
        float time = _Time.y;
        int i = int(modc(time, 9.0));
        if(i==0) cs.y=.58;
        if(i==1) cs.xy=.5;
        if(i==2) cs.xy=.5;
        if(i==3) fu=1.01,cs.x=.9;
        if(i==4) fu=1.01,cs.x=.9;
        if(i==6) cs=float3(.5,.5,1.04);
        if(i==5) fu=.9;
        if(i==7) fd=.7,fs=1.34,cs.xy=.5;
        if(i==8) fc.z=-.38;
    }
    
    //cs += sin(time)*0.2;

    float v=1.;
    for(int i=0; i<12; i++){
        f=2.*clamp(f,-cs,cs)-f;
        float c=max(fs/dot(f,f),1.);
        f*=c;
        v*=c;
        f+=fc;
    }
    float z=length(f.xy)-fu;
    return fd*max(z,abs(length(f.xy)*f.z)/sqrt(dot(f,f)))/abs(v);
}

float pseudo_kleinian(float3 p)
{
    float3 CSize = float3(0.92436,0.90756,0.92436);
    float Size = 1.0;
    float3 C = float3(0,0,0);
    float DEfactor=1.0;
    float3 Offset = float3(0,0,0);
    for(int i=0;i<10 ;i++){
        p=2.*clamp(p, -CSize, CSize)-p;
        float r2 = dot(p,p);
        float k = max(Size/r2,1.);
        p *= k;
        DEfactor *= k + 0.05;
        p += C;
    }
    float r = abs(0.5*abs(p.z-Offset.z)/DEfactor);
    return r;
}

float pseudo_knightyan(float3 p)
{
    float3 CSize = float3(0.63248,0.78632,0.875);
    float DEfactor=1.;
    for(int i=0;i<6;i++){
        p = 2.*clamp(p, -CSize, CSize)-p;
        float k = max(0.70968/dot(p,p),1.);
        p *= k;
        DEfactor *= k + 0.05;
    }
    float rxy=length(p.xy);
    return max(rxy-0.92784, abs(rxy*p.z) / length(p))/DEfactor;
}


float infiniteMenger(in float3 z)
{
	// Folding 'tiling' of 3D space;
	z  = abs(1.0-fmod(z,2.0));

	const int kIterations = 7;
	float Scale = 3.0;
	float3 Offset = float3(0.92858,0.92858,0.32858);

	float d = 1000.0;

	float cosTime = cos(_Time.y/8.0);
	for (int n = 0; n < kIterations; n++)
	{
		z.xy = rotate(z.xy,4.0+2.0*cosTime);
		z = abs(z);
		if (z.x<z.y){ z.xy = z.yx;}
		if (z.x< z.z){ z.xz = z.zx;}
		if (z.y<z.z){ z.yz = z.zy;}
		z = Scale*z-Offset*(Scale-1.0);
		if( z.z<-0.5*Offset.z*(Scale-1.0))  z.z+=Offset.z*(Scale-1.0);
		d = min(d, length(z) * pow(Scale, float(-n)-1.0));
	}
	
	return d-0.001;
}

float kali(float3 pos)
{
	float len = length(pos);
	if (len > 20)
		return len*0.9;

	float4 p = float4(pos,1);
	//float3 param = float3(0.51, 0.5, 1.0+0.5*sin(_Time.x/40.0));
	float3 param = float3(0.52, 0.5, 1.0+0.5*sin(_Time.x));

	float d = 10000.0;
	for (int i = 0; i < 8; ++i)
	{
        p = abs(p) / dot(p.xyz, p.xyz);
        float thickness = 1.5;
        d = min(d, length(p.xy) / (p.w*thickness));
        p.xyz -= param;
	}
	return max(1.0e-5f, d) * 1.0;
}

float kaliHollow(float3 pos)
{
	float d = kali(pos);
	float ds = length(pos)-1.1;
	return max(d, -ds);
}

float kali2(float3 p) {
    float4 q = float4(p - 1.0, 1);
    for(int i = 0; i < 6; i++) {
        q.xyz = abs(q.xyz + 1.1) - 1.1;
        q /= clamp(dot(q.xyz, q.xyz), 0.25, 0.9);
        q *= 1.25;
    }
    return (length(q.yz) - 1.2)/q.w;
    //return max(0, (length(q.xyz) - 0.2)/q.w);
}


#define MAX_MARCH_SINGLE_GBUFFER_PASS 100

float map(float3 p)
{
    //return pseudo_kleinian( (p+float3(0.0, -0.5, 0.0)).xzy );
    //return tglad_formula(p);
    //return pseudo_knightyan( (p+float3(0.0, -0.5, 0.0)).xzy );
    //return kaleidoscopic_IFS(p);
    //return infiniteMenger(p);
    //return hartverdrahtet( (p+float3(0.0, -0.5, 0.0)).xzy );
    //return kali(p);
    //return kali2(p);
    return kaliHollow(p);

    //p = fmod(p+1.5,3.0)-1.5;
    //return length(p) - 0.5;
}

float3 guess_normal(float3 p)
{
    const float d = 0.001;
    return normalize( float3(
        map(p+float3(  d,0.0,0.0))-map(p+float3( -d,0.0,0.0)),
        map(p+float3(0.0,  d,0.0))-map(p+float3(0.0, -d,0.0)),
        map(p+float3(0.0,0.0,  d))-map(p+float3(0.0,0.0, -d)) ));
}

void raymarching(float2 pos, const int num_steps, inout float o_total_distance, out float o_num_steps, out float o_last_distance, out float3 o_raypos)
{
    float3 cam_pos      = getCameraPosition();
    float3 cam_forward  = getCameraForward();
    float3 cam_up       = getCameraUp();
    float3 cam_right    = getCameraRight();
    float  cam_focal_len= getCameraFocalLength();

    float3 ray_dir = normalize(cam_right*pos.x + cam_up*pos.y + cam_forward*cam_focal_len);
    float max_distance = _ProjectionParams.z - _ProjectionParams.y;
    o_raypos = cam_pos + ray_dir * o_total_distance;

    o_num_steps = 0.0;
    o_last_distance = 0.0;
    for(int i=0; i<num_steps; ++i) {
        o_last_distance = map(o_raypos);
        o_total_distance += o_last_distance;
        o_raypos += ray_dir * o_last_distance;
        o_num_steps += 1.0;
        if(o_last_distance < 0.003 || o_total_distance > max_distance) { break; }
    }
    o_total_distance = min(o_total_distance, max_distance);
    if(o_total_distance >= max_distance) { discard; }
}

half4 _Color;
half3 _SpecColor;
half _Smoothness;

gbuffer_out frag(float4 ipos : SV_Position)
{
    float time = _Time.y;
    float2 pos = ipos.xy * (_ScreenParams.zw-1) * 2 - 1;
    pos.x *= _ScreenParams.x / _ScreenParams.y;

    float num_steps = 1.0;
    float last_distance = 0.0;
    float total_distance = _ProjectionParams.y;
    float3 ray_pos;
    float3 normal;
    raymarching(pos, MAX_MARCH_SINGLE_GBUFFER_PASS, total_distance, num_steps, last_distance, ray_pos);
    normal = guess_normal(ray_pos);

    //float c = total_distance*0.1;
    //c.r 
    //float4 color = float4( c + float3(0.02, 0.02, 0.025)*num_steps*0.4, 1.0 );
    //color.xyz += float3(0.5, 0.5, 0.75);
    //color.xyz = float3(1,0,0);
    float4 color = _Color;
    //color.r = total_distance * 0.1;
    //color.r = num_steps * 0.01;

    gbuffer_out o;
    o.diffuse = color;
    o.spec_smoothness = float4(_SpecColor, _Smoothness);
    o.normal = float4(normal*0.5+0.5, 1.0);
    o.emission = 0; // g_hdr ? float4(emission, 1.0) : exp2(float4(-emission, 1.0));
    o.depth = computeDepth(mul(UNITY_MATRIX_VP, float4(ray_pos, 1.0)));
    return o;	
}
ENDCG
		}
	}
}
