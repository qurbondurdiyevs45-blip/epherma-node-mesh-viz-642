<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  export let serviceCount: number = 0;
  export let nodeStatus: 'connecting' | 'online' | 'error' = 'online';

  let selectedTimeRange: number = 24;
  let intensityThreshold: number = 0.5;
  let filterText: string = '';
  let autoRefresh: boolean = true;
  let selectedStacks: string[] = ['Rust', 'Go', 'Node.js', 'Zig', 'C++', 'Java', 'Python'];
  let activeStacks: Set<string> = new Set(selectedStacks);

  function toggleStack(stack: string) {
    if (activeStacks.has(stack)) {
      activeStacks.delete(stack);
    } else {
      activeStacks.add(stack);
    }
    activeStacks = activeStacks;
    updateFilters();
  }

  function updateFilters() {
    dispatch('filterChange', {
      timeRange: selectedTimeRange,
      threshold: intensityThreshold,
      query: filterText.toLowerCase(),
      stacks: Array.from(activeStacks),
      autoRefresh
    });
  }

  $: {
    if (selectedTimeRange || intensityThreshold || filterText || autoRefresh) {
      updateFilters();
    }
  }

  const statusColors = {
    connecting: 'bg-yellow-500',
    online: 'bg-green-500',
    error: 'bg-red-500'
  };
</script>

<aside class="sidebar h-full w-80 bg-slate-900 text-slate-100 flex flex-col border-r border-slate-700 shadow-xl overflow-hidden">
  <div class="p-6 border-b border-slate-800 bg-slate-900/50">
    <div class="flex items-center justify-between mb-2">
      <h1 class="text-xl font-bold tracking-tight text-white uppercase italic">EphemeraNode</h1>
      <div class="flex items-center gap-2">
        <span class="text-[10px] font-mono uppercase text-slate-400">Mesh Status</span>
        <div class="w-3 h-3 rounded-full animate-pulse {statusColors[nodeStatus]}"></div>
      </div>
    </div>
    <p class="text-xs text-slate-400 font-mono">Transient Microservice Viz</p>
  </div>

  <div class="flex-1 overflow-y-auto p-6 space-y-8 scrollbar-thin">
    <!-- Search -->
    <section>
      <label for="search" class="block text-xs font-bold text-slate-500 uppercase mb-3 italic">Node Filter</label>
      <input
        type="text"
        id="search"
        bind:value={filterText}
        placeholder="Enter service ID or tag..."
        class="w-full bg-slate-800 border border-slate-700 rounded px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-cyan-500 transition-all font-mono"
      />
    </section>

    <!-- Range Controls -->
    <section class="space-y-6">
      <div>
        <div class="flex justify-between mb-3 italic">
          <label class="text-xs font-bold text-slate-500 uppercase">Lookback Window</label>
          <span class="text-xs font-mono text-cyan-400">{selectedTimeRange}h</span>
        </div>
        <input 
          type="range" 
          min="1" max="24" 
          bind:value={selectedTimeRange}
          class="w-full accent-cyan-500 bg-slate-800 h-1.5 rounded-lg appearance-none cursor-pointer"
        />
      </div>

      <div>
        <div class="flex justify-between mb-3 italic">
          <label class="text-xs font-bold text-slate-500 uppercase">Heat Sensitivity</label>
          <span class="text-xs font-mono text-cyan-400">{intensityThreshold.toFixed(2)}</span>
        </div>
        <input 
          type="range" 
          min="0" max="1" step="0.05"
          bind:value={intensityThreshold}
          class="w-full accent-cyan-500 bg-slate-800 h-1.5 rounded-lg appearance-none cursor-pointer"
        />
      </div>
    </section>

    <!-- Polyglot Selection -->
    <section>
      <label class="block text-xs font-bold text-slate-500 uppercase mb-3 italic">Stack Monitoring</label>
      <div class="flex flex-wrap gap-2">
        {#each selectedStacks as stack}
          <button
            on:click={() => toggleStack(stack)}
            class="px-2 py-1 text-[10px] font-mono border rounded transition-all duration-200 
            {activeStacks.has(stack) ? 'bg-cyan-900/40 border-cyan-500 text-cyan-200 shadow-[0_0_10px_rgba(6,182,212,0.2)]' : 'bg-slate-800 border-slate-700 text-slate-500 opacity-60'}"
          >
            {stack}
          </button>
        {/each}
      </div>
    </section>

    <!-- Stats -->
    <section class="bg-slate-950/50 p-4 rounded border border-slate-800/50">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <span class="block text-[10px] text-slate-500 uppercase font-bold italic">Active Nodes</span>
          <span class="text-2xl font-mono text-white tracking-widest leading-none">{serviceCount.toLocaleString()}</span>
        </div>
        <div>
          <span class="block text-[10px] text-slate-500 uppercase font-bold italic">WebGL Buffers</span>
          <span class="text-2xl font-mono text-white tracking-widest leading-none">64bit</span>
        </div>
      </div>
    </section>
  </div>

  <!-- Footer Controls -->
  <div class="p-6 border-t border-slate-800 bg-slate-950">
    <label class="flex items-center cursor-pointer group">
      <input type="checkbox" bind:checked={autoRefresh} class="hidden" />
      <div class="w-8 h-4 bg-slate-800 rounded-full mr-3 relative transition-colors duration-200 {autoRefresh ? 'bg-cyan-600' : ''}">
        <div class="absolute top-0.5 left-0.5 w-3 h-3 bg-white rounded-full transition-transform duration-200 {autoRefresh ? 'translate-x-4' : ''}"></div>
      </div>
      <span class="text-xs font-bold uppercase transition-colors {autoRefresh ? 'text-cyan-400' : 'text-slate-500'}">Real-time Sync</span>
    </label>
    <button 
      class="mt-4 w-full py-2 bg-slate-100 text-slate-900 text-xs font-bold uppercase rounded hover:bg-cyan-400 transition-colors"
      on:click={() => dispatch('export')}
    >
      Export Snapshot
    </button>
  </div>
</aside>

<style>
  .scrollbar-thin::-webkit-scrollbar {
    width: 4px;
  }
  .scrollbar-thin::-webkit-scrollbar-track {
    background: transparent;
  }
  .scrollbar-thin::-webkit-scrollbar-thumb {
    background: #334155;
    border-radius: 2px;
  }
  .sidebar {
    user-select: none;
  }
</style>