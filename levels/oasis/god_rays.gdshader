shader_type canvas_item;
render_mode blend_add;
const mat2 myt=mat2(vec2(.12121212,.13131313),vec2(-.13131313,.12121212));
const vec2 mys=vec2(1e4,1e6);

vec2 rhash(vec2 uv){
    uv*=myt;
    uv*=mys;
    return fract(fract(uv/mys)*uv);
}

vec3 hash(vec3 p){
    return fract(sin(vec3(dot(p,vec3(1.,57.,113.)),
    dot(p,vec3(57.,113.,1.)),
    dot(p,vec3(113.,1.,57.))))* 43758.5453);
}

float voronoi2d(const in vec2 point)
{
	vec2 p=floor(point);
	vec2 f=fract(point);
	float res=0.;
	for(int j=-1;j<=1;j++){
	    for(int i=-1;i<=1;i++){
	        vec2 b=vec2(float(i), float(j));
	        vec2 r=vec2(b)-f+rhash(p+b);
	        res+=1./pow(dot(r,r),8.);
	    }
	}
	return pow(1./res,.0625);
}

vec2 cart2polar(vec2 uv){
	float phi=atan(uv.y,uv.x);
	float r=length(uv);
	return vec2(phi,r);
}

void fragment(){
	vec2 uv=UV;
	uv.y = 1. - uv.y;
	vec2 p = uv;

	uv.y-=2.;
	//uv/=50.;
	uv=cart2polar(uv);

	float n1=voronoi2d((vec2(uv.x,0.)+.0025*TIME)*10.);

	float n2=voronoi2d((vec2(.1,uv.x)-.005*TIME*1.5)*20.);

	float n3=mix(n1, n2, clamp((n1 / n2), 0.01, 1.)); //min(n1,n2);

	float mask=smoothstep(.0,.86,p.y);
	float alpha=n3*mask*(.8 + 0.1 * n1 + 0.15 * n2);

	vec3 col=mix(vec3(0.7),vec3(1.),alpha);

	COLOR=vec4(col, alpha * alpha);
}