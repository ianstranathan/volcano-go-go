shader_type canvas_item;


uniform sampler2D noise_tex:repeat_enable;

mat2 makem2(in float theta)
{
	float c = cos(theta);
	float s = sin(theta);
	return mat2(vec2(c,-s), vec2(s,c));
}
float noise( in vec2 x )
{
	return texture(noise_tex, x*.01).x;
}

float fbm(in vec2 p)
{	
	vec4 tt=fract(vec4(TIME*1.5)+vec4(0.0,0.25,0.5,0.75));
	vec2 p1=p-normalize(p)*tt.x;
	vec2 p2=vec2(1.0)+p-normalize(p)*tt.y;
	vec2 p3=vec2(2.0)+p-normalize(p)*tt.z;
	vec2 p4=vec2(3.0)+p-normalize(p)*tt.w;
	vec4 tr=vec4(1.0)-abs(tt-vec4(0.5))*2.0;//*vec4(0.0,1.0,0.0,1.0);
	float z=2.;
	vec4 rz = vec4(0.);
	for (float i= 1.;i < 4.;i++)
	{
		rz+= abs((vec4(noise(p1),noise(p2),noise(p3),noise(p4))-vec4(0.5))*2.)/z;
		z = z*2.;
		p1 = p1*2.;
		p2 = p2*2.;
		p3 = p3*2.;
		p4 = p4*2.;
	}
	return dot(rz,tr)*0.25;
}
float dualfbm(in vec2 p)
{
    //get two rotated fbm calls and displace the domain
	vec2 p2 = p*.7;
	vec2 basis = vec2(fbm(p2-TIME*1.6),fbm(p2+TIME*1.7));
	basis = (basis-.5)*.2;
	p += basis;
	
	//coloring
	return fbm(p); //*makem2(TIME*2.0));
}

float circ(vec2 p) 
{
	float r = length(p);
	r = log(sqrt(r));
	return abs(mod(r*2.,TAU)-4.54)*3.+.5;

}

float sdEllipse( in vec2 p, in vec2 ab )
{
    p = abs(p); if( p.x > p.y ) {p=p.yx;ab=ab.yx;}
    float l = ab.y*ab.y - ab.x*ab.x;
    float m = ab.x*p.x/l;      float m2 = m*m; 
    float n = ab.y*p.y/l;      float n2 = n*n; 
    float c = (m2+n2-1.0)/3.0; float c3 = c*c*c;
    float q = c3 + m2*n2*2.0;
    float d = c3 + m2*n2;
    float g = m + m*n2;
    float co;
    if( d<0.0 )
    {
        float h = acos(q/c3)/3.0;
        float s = cos(h);
        float t = sin(h)*sqrt(3.0);
        float rx = sqrt( -c*(s + t + 2.0) + m2 );
        float ry = sqrt( -c*(s - t + 2.0) + m2 );
        co = (ry+sign(l)*rx+abs(g)/(rx*ry)- m)/2.0;
    }
    else
    {
        float h = 2.0*m*n*sqrt( d );
        float s = sign(q+h)*pow(abs(q+h), 1.0/3.0);
        float u = sign(q-h)*pow(abs(q-h), 1.0/3.0);
        float rx = -s - u - c*4.0 + 2.0*m2;
        float ry = (s - u)*sqrt(3.0);
        float rm = sqrt( rx*rx + ry*ry );
        co = (ry/sqrt(rm-rx)+2.0*g/rm-m)/2.0;
    }
    vec2 r = ab * vec2(co, sqrt(1.0-co*co));
    return length(r-p) * sign(p.y-r.y);
}

uniform sampler2D oasis_tex;
uniform sampler2D volcano_tex;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.1;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.5;
uniform float wave_frequency : hint_range(0.1, 10.0) = 2.0;

uniform float is_volcano = 0.0;
void fragment()
{
	vec2 uv = 2. * UV - 1.;
	vec2 moving_uv = UV * wave_frequency;
	moving_uv.x += TIME * wave_speed * 0.5;
    moving_uv.y += TIME * wave_speed * 0.3; // slightly different speed for organic look

    //vec2 distortion = (noise.rg * 2.0 - 1.0) * distortion_strength;
	vec2 distortion = vec2(0.);
    
    distortion.x += sin(UV.y * 10.0 + TIME * wave_speed) * distortion_strength * 0.3;
    distortion.y += cos(UV.x * 10.0 + TIME * wave_speed) * distortion_strength * 0.3;

	vec4 oasis_tex_sample   = texture(oasis_tex,   (2. *  (UV - vec2(0.5)) + vec2(0.5)) + distortion) *  (1. - step(0.1, is_volcano));
	vec4 volcano_tex_sample = texture(volcano_tex, (1. * (UV - vec2(0.5)) + vec2(0.5)) + distortion - vec2(0., 0.05)) *  step(0.1, is_volcano);
	vec4 inner_tex_sample = oasis_tex_sample + volcano_tex_sample;
   //vec4 inner_tex_sample = texture(oasis_tex, (2. * (UV - vec2(0.5)) + vec2(0.5)) + distortion) *  (1. - step(0.1, is_volcano) +


	vec2 p = UV - 0.5;
	p*=5.;
	
    float rz = dualfbm(p);

    
    rz *= abs((-circ(vec2(p.x / 4.2, p.y / 7.0))));
	
    rz *= abs((-circ(vec2(p.x / 4.2, p.y / 7.0))));
	
    rz *= abs((-circ(vec2(p.x / 4.2, p.y / 7.0))));
	
	//final color
	vec3 base_col =  (1. -  step(0.1, is_volcano))* vec3(.1,0.1,0.4)  + step(0.1, is_volcano) * vec3(0.4, 0.1, 0.1);
	vec3 col = base_col/rz;
	col=pow(abs(col),vec3(.99));
	COLOR = vec4(col, 1. - (rz * rz));
	//_out = inner_tex_sample.xyz * (1. - inner_mask) * (rz * rz);
	float d = sdEllipse(uv, vec2(0.3, 0.5));
	float inner_mask = 1. - smoothstep(0., 0.01, d);
	
	
	//vec3 _out = inner_mask * clamp((rz * rz), 0., 1) * inner_tex_sample.xyz + col * (1. - inner_mask) * (1. -  clamp((rz * rz), 0., 1));
	COLOR = vec4(mix(col, inner_tex_sample.xyz * inner_mask, pow(abs(d), 0.1) ),
				 pow(col.r + inner_mask, 4.));
}