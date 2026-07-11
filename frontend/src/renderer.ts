export class EphemeralNodeRenderer {
    private canvas: HTMLCanvasElement;
    private gl: WebGL2RenderingContext;
    private program: WebGLProgram;
    private instanceBuffer: WebGLBuffer | null = null;
    private nodeCount: number = 0;

    private readonly MAX_NODES = 50000;
    private readonly ATTRIB_LOCATIONS = {
        position: 0,
        offset: 1,
        color: 2,
        scale: 3
    };

    constructor(canvas: HTMLCanvasElement) {
        this.canvas = canvas;
        const gl = canvas.getContext('webgl2', { antialias: true, alpha: false });
        if (!gl) {
            throw new Error('WebGL2 not supported');
        }
        this.gl = gl;
        this.program = this.createProgram();
        this.initBuffers();
    }

    private createProgram(): WebGLProgram {
        const vsSource = `#version 300 es
            layout(location = 0) in vec2 a_position;
            layout(location = 1) in vec3 a_offset;
            layout(location = 2) in vec4 a_color;
            layout(location = 3) in float a_scale;
            
            uniform vec2 u_resolution;
            uniform float u_time;
            
            out vec4 v_color;

            void main() {
                vec2 visualOffset = a_offset.xy;
                // Add subtle oscillation for transient feel
                float pulse = sin(u_time * 2.0 + a_offset.z) * 0.05;
                vec2 position = a_position * (a_scale + pulse) + visualOffset;
                
                // Convert screen space to clip space
                vec2 clipSpace = (position / u_resolution) * 2.0 - 1.0;
                gl_Position = vec4(clipSpace * vec2(1, -1), 0, 1);
                v_color = a_color;
            }
        `;

        const fsSource = `#version 300 es
            precision highp float;
            in vec4 v_color;
            out vec4 outColor;
            void main() {
                float dist = distance(gl_PointCoord, vec2(0.5));
                outColor = v_color;
            }
        `;

        const vs = this.compileShader(this.gl.VERTEX_SHADER, vsSource);
        const fs = this.compileShader(this.gl.FRAGMENT_SHADER, fsSource);
        const program = this.gl.createProgram()!;
        this.gl.attachShader(program, vs);
        this.gl.attachShader(program, fs);
        this.gl.linkProgram(program);

        if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
            throw new Error(this.gl.getProgramInfoLog(program) || 'Link error');
        }
        return program;
    }

    private compileShader(type: number, source: string): WebGLShader {
        const shader = this.gl.createShader(type)!;
        this.gl.shaderSource(shader, source);
        this.gl.compileShader(shader);
        if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
            throw new Error(this.gl.getShaderInfoLog(shader) || 'Shader error');
        }
        return shader;
    }

    private initBuffers(): void {
        const gl = this.gl;
        
        // Quad for instanced rendering
        const vertices = new Float32Array([
            -0.5, -0.5,
             0.5, -0.5,
            -0.5,  0.5,
             0.5,  0.5,
        ]);

        const vao = gl.createVertexArray();
        gl.bindVertexArray(vao);

        const vbo = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
        gl.enableVertexAttribArray(this.ATTRIB_LOCATIONS.position);
        gl.vertexAttribPointer(this.ATTRIB_LOCATIONS.position, 2, gl.FLOAT, false, 0, 0);

        this.instanceBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, this.instanceBuffer);
        // Pre-allocate buffer for 50k nodes (x, y, z, r, g, b, a, scale)
        gl.bufferData(gl.ARRAY_BUFFER, this.MAX_NODES * 8 * 4, gl.DYNAMIC_DRAW);

        // offset (x, y, z) - 3 floats
        gl.enableVertexAttribArray(this.ATTRIB_LOCATIONS.offset);
        gl.vertexAttribPointer(this.ATTRIB_LOCATIONS.offset, 3, gl.FLOAT, false, 8 * 4, 0);
        gl.vertexAttribDivisor(this.ATTRIB_LOCATIONS.offset, 1);

        // color (r, g, b, a) - 4 floats
        gl.enableVertexAttribArray(this.ATTRIB_LOCATIONS.color);
        gl.vertexAttribPointer(this.ATTRIB_LOCATIONS.color, 4, gl.FLOAT, false, 8 * 4, 3 * 4);
        gl.vertexAttribDivisor(this.ATTRIB_LOCATIONS.color, 1);

        // scale - 1 float
        gl.enableVertexAttribArray(this.ATTRIB_LOCATIONS.scale);
        gl.vertexAttribPointer(this.ATTRIB_LOCATIONS.scale, 1, gl.FLOAT, false, 8 * 4, 7 * 4);
        gl.vertexAttribDivisor(this.ATTRIB_LOCATIONS.scale, 1);
    }

    public updateData(nodeData: Float32Array): void {
        this.nodeCount = nodeData.length / 8;
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.instanceBuffer);
        this.gl.bufferSubData(this.gl.ARRAY_BUFFER, 0, nodeData);
    }

    public render(time: number): void {
        const gl = this.gl;
        gl.viewport(0, 0, this.canvas.width, this.canvas.height);
        gl.clearColor(0.05, 0.05, 0.08, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        gl.useProgram(this.program);
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        const resLoc = gl.getUniformLocation(this.program, 'u_resolution');
        gl.uniform2f(resLoc, this.canvas.width, this.canvas.height);

        const timeLoc = gl.getUniformLocation(this.program, 'u_time');
        gl.uniform1f(timeLoc, time * 0.001);

        gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, this.nodeCount);
    }

    public resize(width: number, height: number): void {
        this.canvas.width = width * window.devicePixelRatio;
        this.canvas.height = height * window.devicePixelRatio;
        this.canvas.style.width = `${width}px`;
        this.canvas.style.height = `${height}px`;
    }
}