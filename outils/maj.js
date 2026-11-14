// Lisière — la mise à jour de l'application installée (outils/maj.js ; outils/pwa.js le pose dans index.html)
// Le service worker garde le jeu sur l'appareil : une fois installé, c'est sa copie qui s'ouvre, pas celle du site. Une version
// nouvelle n'arrivait qu'à la deuxième ouverture après sa publication, et encore : le navigateur ne la cherchait pas tout de suite,
// et le jeu n'apprenait pas toujours qu'elle était prête. Ici :
//  - on la cherche dès l'ouverture (et à chaque retour à l'écran-titre : chercher) ;
//  - on suit son installation, d'où qu'elle en soit quand la page s'ouvre ;
//  - prête avant que le jeu ait démarré, la page se recharge aussitôt sur elle ; ensuite c'est le jeu qui décide (à l'écran-titre,
//    jamais pendant une partie : scripts/principal.gd, _nouvelle_version) ;
//  - version : quand ce jeu-ci a été exporté (secondes Unix), pour le dire à l'écran-titre.
(function () {
	var M = window.lisiereMaj = { version: __VERSION__, prete: false, jeu: false, appliquer: function () {}, chercher: function () {} };
	if (!('serviceWorker' in navigator)) {
		return;
	}
	function appliquer(reg) {
		if (reg.waiting) {
			reg.waiting.postMessage('update');
		}
	}
	function prete(reg) {
		M.prete = true;
		M.appliquer = function () { appliquer(reg); };
		if (!M.jeu) {
			appliquer(reg);
		}
	}
	function suivre(reg, w) {
		if (!w) {
			return;
		}
		w.addEventListener('statechange', function () {
			// (« installed » sans service worker aux commandes : une première installation, pas une mise à jour)
			if (w.state === 'installed' && navigator.serviceWorker.controller) {
				prete(reg);
			}
		});
	}
	navigator.serviceWorker.getRegistration().then(function (reg) {
		if (!reg) {
			return;
		}
		M.chercher = function () { reg.update().catch(function () {}); };
		if (reg.waiting && navigator.serviceWorker.controller) {
			prete(reg);
		}
		suivre(reg, reg.installing);
		reg.addEventListener('updatefound', function () { suivre(reg, reg.installing); });
		M.chercher();
	}).catch(function () {});
}());
