<template>
  <div class="ephema-node-container">
    <header class="top-bar">
      <div class="brand">
        <div class="logo-orb"></div>
        <h1>EPHEMA<span class="accent">NODE</span> MESH VIZ</h1>
      </div>
      <div class="stats-ribbon">
        <div class="stat-item">
          <span class="label">ACTIVE NODES:</span>
          <span class="value">{{ activeNodes }}</span>
        </div>
        <div class="stat-item">
          <span class="label">24H FAILURES:</span>
          <span class="value critical">{{ totalFailures }}</span>
        </div>
        <div class="stat-item">
          <span class="label">LATENCY:</span>
          <span class="value">{{ avgLatency }}ms</span>
        </div>
      </div>
      <div class="controls">
        <button @click="toggleRealtime" :class="{ 'is-active': isRealtime }">
          {{ isRealtime ? 'LIVE' : 'PAUSED' }}
        </button>
        <button @click="resetView">RESET PERSPECTIVE</button>
      </div>
    </header>

    <main class="visualizer-shell">
      <canvas ref="glCanvas" id="mesh-canvas"></canvas>
      
      <aside class="side-panel overlay">
        <section class="stack-health">
          <h3>POLYGLOT ECOSYSTEM</h3>
          <div v-for="(status, lang) in stackHealth" :key="lang" class="health-bar-row">
            <span class="lang-tag">{{ lang }}</span>
            <div class="bar-bg">
              <div class="bar-fill" :style="{ width: status + '%', backgroundColor: getHealthColor(status) }"></div>
            </div>
          </div>
        </section>

        <section class="event-log">
          <h3>TRANSIENT ANOMALIES</h3>
          <transition-group name="list" tag="div">
            <div v-for="log in recentLogs" :key="log.id" class="log-entry">
              <span class="log-time">{{ log.time }}</span>
              <span class="log-msg">{{ log.message }}</span>
            </div>
          </transition-group>
        </section>
      </aside>
    </main>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted, onBeforeUnmount } from 'vue';

export default defineComponent({
  name: 'App',
  setup() {
    const glCanvas = ref<HTMLCanvasElement | null>(null);
    const activeNodes = ref(12408);
    const totalFailures = ref(482);
    const avgLatency = ref(42);
    const isRealtime = ref(true);
    
    const stackHealth = ref({
      'Rust': 98,
      'Go': 92,
      'Zig': 100,
      'C++': 85,
      'Node.js': 76,
      'Python': 64,
      'Swift': 89
    });

    const recentLogs = ref([
      { id: 1, time: '14:20:01', message: 'gRPC Timeout - Auth-Service (Go)' },
      { id: 2, time: '14:20:05', message: 'Malloc Failure - Image-Proc (C++)' },
      { id: 3, time: '14:20:12', message: 'Segmentation Fault - Worker-X (Rust)' }
    ]);

    const getHealthColor = (val: number) => {
      if (val > 90) return '#00ffaa';
      if (val > 70) return '#ffcc00';
      return '#ff4444';
    };

    const toggleRealtime = () => {
      isRealtime.value = !isRealtime.value;
    };

    const resetView = () => {
      console.log("Resetting WebGL Camera...");
    };

    onMounted(() => {
      if (glCanvas.value) {
        // Initialize WebGL context and load mesh visualizer shaders
        const gl = glCanvas.value.getContext('webgl2');
        if (gl) {
          gl.clearColor(0.02, 0.02, 0.05, 1.0);
          gl.clear(gl.COLOR_BUFFER_BIT);
        }
      }

      // Simulate live jitter
      const interval = setInterval(() => {
        if (isRealtime.value) {
          avgLatency.value = 40 + Math.floor(Math.random() * 10);
        }
      }, 2000);

      onBeforeUnmount(() => clearInterval(interval));
    });

    return {
      glCanvas,
      activeNodes,
      totalFailures,
      avgLatency,
      isRealtime,
      stackHealth,
      recentLogs,
      getHealthColor,
      toggleRealtime,
      resetView
    };
  }
});
</script>

<style scoped>
.ephema-node-container {
  display: flex;
  flex-direction: column;
  width: 100vw;
  height: 100vh;
  background: #050508;
  color: #e0e0e0;
  font-family: 'Inter', system-ui, sans-serif;
  overflow: hidden;
}

.top-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 2rem;
  height: 60px;
  background: rgba(15, 15, 25, 0.9);
  border-bottom: 1px solid #222533;
  backdrop-filter: blur(10px);
  z-index: 100;
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-orb {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: radial-gradient(circle, #00f2fe 0%, #0072ff 100%);
  box-shadow: 0 0 15px rgba(0, 242, 254, 0.6);
}

h1 {
  font-size: 1.1rem;
  letter-spacing: 2px;
  margin: 0;
  font-weight: 800;
}

.accent { color: #00f2fe; }

.stats-ribbon {
  display: flex;
  gap: 40px;
}

.stat-item {
  display: flex;
  flex-direction: column;
}

.label {
  font-size: 0.65rem;
  color: #888;
}

.value {
  font-family: 'JetBrains Mono', monospace;
  font-size: 1rem;
  color: #fff;
}

.critical { color: #ff4444; }

.visualizer-shell {
  flex: 1;
  position: relative;
}

#mesh-canvas {
  width: 100%;
  height: 100%;
}

.side-panel {
  position: absolute;
  top: 20px;
  right: 20px;
  width: 320px;
  bottom: 20px;
  background: rgba(10, 10, 15, 0.85);
  border: 1px solid #333;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 2rem;
  pointer-events: all;
  border-radius: 4px;
}

.health-bar-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
}

.lang-tag {
  width: 70px;
  font-size: 0.75rem;
  font-weight: bold;
}

.bar-bg {
  flex: 1;
  height: 8px;
  background: #1a1a25;
  border-radius: 4px;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  transition: width 0.5s ease;
}

.event-log {
  flex: 1;
  overflow-y: auto;
}

.log-entry {
  font-size: 0.7rem;
  padding: 8px 0;
  border-bottom: 1px solid #222;
  font-family: 'JetBrains Mono', monospace;
}

.log-time { color: #00f2fe; margin-right: 8px; }

button {
  background: #1a1a2e;
  border: 1px solid #333;
  color: #fff;
  padding: 6px 16px;
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
  margin-left: 10px;
}

button:hover { background: #2a2a45; border-color: #00f2fe; }

button.is-active {
  background: #00f2fe;
  color: #000;
  font-weight: bold;
}
</style>