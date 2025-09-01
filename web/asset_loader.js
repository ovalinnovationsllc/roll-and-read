// Asset preloader for Flutter Web
(function() {
  'use strict';
  
  // Preload critical assets to prevent 404 errors
  function preloadAssets() {
    const criticalAssets = [
      'assets/AssetManifest.bin.json',
      'assets/AssetManifest.json',
      'assets/FontManifest.json'
    ];
    
    criticalAssets.forEach(asset => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.as = 'fetch';
      link.href = asset;
      link.crossOrigin = 'anonymous';
      document.head.appendChild(link);
    });
  }
  
  // Run preloader when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', preloadAssets);
  } else {
    preloadAssets();
  }
})();