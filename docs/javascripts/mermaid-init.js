// Mermaid initialization for MkDocs Material
document.addEventListener("DOMContentLoaded", function() {
  // Initialize Mermaid with configuration
  mermaid.initialize({
    startOnLoad: true,
    theme: 'default',
    securityLevel: 'loose',
    themeVariables: {
      primaryColor: '#1976d2',
      primaryTextColor: '#ffffff',
      primaryBorderColor: '#1976d2',
      lineColor: '#1976d2',
      secondaryColor: '#f5f5f5',
      tertiaryColor: '#e8f4fd'
    },
    flowchart: {
      useMaxWidth: true,
      htmlLabels: true
    },
    gitGraph: {
      useMaxWidth: true
    }
  });

  // Find and render all Mermaid diagrams
  const mermaidElements = document.querySelectorAll('.mermaid');
  if (mermaidElements.length > 0) {
    console.log('Found ' + mermaidElements.length + ' Mermaid diagrams');
    mermaidElements.forEach(function(element, index) {
      // Ensure each diagram has a unique ID
      if (!element.id) {
        element.id = 'mermaid-diagram-' + index;
      }
    });
    
    // Re-render if needed
    mermaid.init(undefined, '.mermaid');
  } else {
    console.log('No Mermaid diagrams found');
  }
});

// Also handle dynamic content loading
if (typeof window !== 'undefined') {
  window.addEventListener('load', function() {
    // Double-check for any missed diagrams
    setTimeout(function() {
      const remainingDiagrams = document.querySelectorAll('.mermaid:not([data-processed])');
      if (remainingDiagrams.length > 0) {
        console.log('Processing ' + remainingDiagrams.length + ' remaining diagrams');
        mermaid.init(undefined, remainingDiagrams);
      }
    }, 1000);
  });
}