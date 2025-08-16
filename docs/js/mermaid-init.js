// Simple Mermaid initialization for GitHub Pages
console.log('Mermaid init script loaded');

document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, checking for Mermaid...');
    
    if (typeof mermaid !== 'undefined') {
        console.log('Mermaid library found, initializing...');
        
        // Initialize Mermaid
        mermaid.initialize({
            startOnLoad: false,
            theme: 'default',
            securityLevel: 'loose'
        });
        
        // Find all div.mermaid elements and render them
        const mermaidDivs = document.querySelectorAll('div.mermaid');
        console.log('Found ' + mermaidDivs.length + ' div.mermaid elements');
        
        if (mermaidDivs.length > 0) {
            mermaid.run();
            console.log('Mermaid rendering complete');
        } else {
            // If no div.mermaid, try to convert pre.mermaid code blocks
            const mermaidPres = document.querySelectorAll('pre.mermaid code');
            console.log('Found ' + mermaidPres.length + ' pre.mermaid code blocks to convert');
            
            mermaidPres.forEach(function(code, index) {
                const div = document.createElement('div');
                div.className = 'mermaid';
                div.textContent = code.textContent;
                div.id = 'mermaid-' + index;
                
                // Replace the pre element with the div
                code.parentElement.parentNode.replaceChild(div, code.parentElement);
                console.log('Converted code block ' + (index + 1));
            });
            
            // Now run mermaid on the converted elements
            setTimeout(function() {
                mermaid.run();
                console.log('Mermaid rendering complete after conversion');
            }, 100);
        }
    } else {
        console.error('Mermaid library not found!');
    }
});

// Also try on window load as backup
window.addEventListener('load', function() {
    console.log('Window loaded, backup Mermaid check...');
    if (typeof mermaid !== 'undefined' && document.querySelectorAll('.mermaid').length > 0) {
        setTimeout(function() {
            mermaid.run();
            console.log('Backup Mermaid rendering complete');
        }, 500);
    }
});