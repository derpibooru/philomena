function gunny_u_onload(g_manifest) {
	
	if ('serviceWorker' in navigator) {
		navigator.serviceWorker.register('g.app.sw.js', { scope: g_manifest.webmanifest.scope })
			.then(function (registration) {
				if (typeof afterServiceWorkerRegistration === "function") { 
					afterServiceWorkerRegistration(registration);
				}
			})
	}
	
	$("#gunny_content").load( "_content.html", function() {gunny_setLoadPercent(gunny_getLoadPercent() + 25);});
	
	// Add navigator lists
	gunny_navAdd('home', 'Home');
	gunny_navAdd('test', 'Test');
	
	// Add JavaScript functions for the navigator lists
	gunny_navAddAction('home', function(){alert('Hello World')});
	
	// Remove a certain navigator list
	gunny_navDelete('test');

}