pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// System measurements: CPU (a short history), memory, battery.
// SUPERCALC_SIMULATION=1 replaces the hardware readings with fixed values (testing without a battery).
Singleton {
	id: root
	readonly property bool simulation: Quickshell.env("SUPERCALC_SIMULATION") === "1"

	// --- CPU ---
	property real cpu: 0                  // 0..1
	property var historiqueCpu: [0, 0, 0, 0, 0, 0, 0, 0]
	property var _precedent: null

	// --- memory ---
	property real memoireUtilisee: 0      // GiB
	property real memoireTotale: 0

	// --- battery ---
	readonly property var batterie: UPower.displayDevice
	readonly property bool aBatterie: simulation || (batterie && batterie.isLaptopBattery && batterie.isPresent)
	readonly property real niveau: simulation ? 0.74 : (batterie ? batterie.percentage : 0)
	readonly property bool enCharge: simulation ? false : !UPower.onBattery
	readonly property real secondesRestantes: simulation ? 11400 : (batterie ? batterie.timeToEmpty : 0)

	FileView { id: stat; path: "/proc/stat"; blockLoading: true }
	FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }

	function mesurer() {
		stat.reload();
		const ligne = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
		const inactif = ligne[3] + (ligne[4] ?? 0);
		const total = ligne.reduce((a, b) => a + b, 0);
		if (root._precedent) {
			const dt = total - root._precedent.total;
			const di = inactif - root._precedent.inactif;
			root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
			root.historiqueCpu = root.historiqueCpu.slice(1).concat([root.cpu]);
		}
		root._precedent = { total, inactif };

		meminfo.reload();
		const m = {};
		for (const l of meminfo.text().split("\n")) {
			const p = l.split(/:\s+/);
			if (p.length === 2) m[p[0]] = parseInt(p[1]);
		}
		if (m.MemTotal) {
			root.memoireTotale = m.MemTotal / 1048576;
			root.memoireUtilisee = (m.MemTotal - (m.MemAvailable ?? m.MemFree)) / 1048576;
		}
	}

	Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.mesurer() }
}
