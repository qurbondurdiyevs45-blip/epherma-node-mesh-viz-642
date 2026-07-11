import React, { useMemo } from 'react';

interface NodeMetadata {
  id: string;
  service: string;
  language: string;
  failureCount: number;
  avgLatency: number;
  lastError: string;
  uptime: string;
}

interface OverlayProps {
  activeNode: NodeMetadata | null;
  mousePos: { x: number; y: number };
  containerWidth: number;
  containerHeight: number;
}

const Overlay: React.FC<OverlayProps> = ({ activeNode, mousePos, containerWidth, containerHeight }) => {
  if (!activeNode) return null;

  const tooltipWidth = 280;
  const tooltipHeight = 160;
  
  // Calculate positioning to keep tooltip within viewport
  const padding = 20;
  let x = mousePos.x + padding;
  let y = mousePos.y + padding;

  if (x + tooltipWidth > containerWidth) {
    x = mousePos.x - tooltipWidth - padding;
  }
  if (y + tooltipHeight > containerHeight) {
    y = mousePos.y - tooltipHeight - padding;
  }

  const getLanguageColor = (lang: string): string => {
    const colors: Record<string, string> = {
      Rust: '#dea584',
      Go: '#00add8',
      TypeScript: '#3178c6',
      Python: '#3776ab',
      Zig: '#ec915c',
      Cpp: '#f34b7d',
      Java: '#b07219'
    };
    return colors[lang] || '#ffffff';
  };

  const statusColor = activeNode.failureCount > 0 ? '#ff4d4d' : '#00ff88';

  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        pointerEvents: 'none',
        zIndex: 100,
      }}
    >
      <svg
        width="100%"
        height="100%"
        style={{ filter: 'drop-shadow(0px 4px 12px rgba(0,0,0,0.5))' }}
      >
        <g transform={`translate(${x}, ${y})`}>
          {/* Hexagonal Background Pattern */}
          <path
            d={`M 0 10 L ${tooltipWidth} 0 L ${tooltipWidth} ${tooltipHeight - 10} L 0 ${tooltipHeight} Z`}
            fill="rgba(13, 17, 23, 0.95)"
            stroke={statusColor}
            strokeWidth="1.5"
          />
          
          {/* Header Accent */}
          <rect
            x="0"
            y="0"
            width="4"
            height="40"
            fill={getLanguageColor(activeNode.language)}
          />

          {/* Node ID and Service Name */}
          <text x="15" y="25" fill="#ffffff" fontSize="14" fontWeight="600" fontFamily="JetBrains Mono, monospace">
            {activeNode.service.toUpperCase()}
          </text>
          <text x="15" y="42" fill="#8b949e" fontSize="10" fontFamily="Inter, sans-serif">
            ID: {activeNode.id}
          </text>

          {/* Metrics Grid */}
          <line x1="15" y1="55" x2={tooltipWidth - 15} y2="55" stroke="#30363d" strokeWidth="1" />
          
          <text x="15" y="75" fill="#8b949e" fontSize="10">RUNTIME</text>
          <text x="15" y="90" fill={getLanguageColor(activeNode.language)} fontSize="12" fontWeight="bold">
            {activeNode.language}
          </text>

          <text x="100" y="75" fill="#8b949e" fontSize="10">LATENCY</text>
          <text x="100" y="90" fill="#ffffff" fontSize="12" fontWeight="bold">
            {activeNode.avgLatency}ms
          </text>

          <text x="185" y="75" fill="#8b949e" fontSize="10">FAILURES (24H)</text>
          <text x="185" y="90" fill={statusColor} fontSize="12" fontWeight="bold">
            {activeNode.failureCount}
          </text>

          {/* Detailed Error Log Hook */}
          <rect x="15" y="105" width={tooltipWidth - 30} height="40" rx="4" fill="#161b22" />
          <text x="22" y="120" fill="#8b949e" fontSize="9">LATEST_EXCEPTION</text>
          <text x="22" y="135" fill="#f85149" fontSize="10" style={{ fontFamily: 'monospace' }}>
            {activeNode.lastError.length > 35 ? activeNode.lastError.substring(0, 35) + '...' : activeNode.lastError}
          </text>

          {/* Interactive Decoration Lines */}
          <circle cx="0" cy="10" r="3" fill={statusColor} />
          <path
            d={`M ${tooltipWidth} 20 L ${tooltipWidth + 15} 5`}
            stroke={statusColor}
            strokeWidth="1"
            fill="none"
          />
        </g>
      </svg>
    </div>
  );
};

export default Overlay;