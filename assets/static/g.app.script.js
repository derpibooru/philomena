if ('serviceWorker' in navigator) {
	navigator.serviceWorker.register('g.app.sw.js', { scope: '/' })
	.then(function (registration) {
		if (typeof afterServiceWorkerRegistration === "function") { 
			afterServiceWorkerRegistration(registration);
		}
	})
}
