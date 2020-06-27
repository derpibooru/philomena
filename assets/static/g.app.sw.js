/*global self, console*/
/*eslint no-undef: */
/*eslint no-unused-vars: */
var CACHE = 'gunny-sw-cache';
var OFFLINE_PAGE_URL = '/gunny_resource/html/offline.html';
								
self.addEventListener('install', function (event) {
	console.log('The GUNNY Engine (app.sw.js): The service worker is being installed.');
							
	// Store "Offline" page
	var offlineRequest = new Request(OFFLINE_PAGE_URL);
	event.waitUntil(
		fetch(offlineRequest).then(function (response) {
			return caches.open('offline').then(function (cache) {
					console.log('The GUNNY Engine (app.sw.js): [oninstall] Cached offline page', response.url);
					return cache.put(offlineRequest, response);
				});
		})
	);
});
self.addEventListener('fetch', function (event) {
	var request = event.request;
	
	// Check is "page" request
	if (request.method === 'GET' && request.destination === 'document') {
		event.respondWith(
			fetch(request).catch(function (error) {
			console.error('The GUNNY Engine (app.sw.js): [onfetch] Failed. Serving cached offline fallback ' + error);
			return caches.open('offline').then(function (cache) {
					return cache.match(OFFLINE_PAGE_URL);
				});
			})
		);
	}
});
