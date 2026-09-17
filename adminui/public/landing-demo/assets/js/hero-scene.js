/* Hero backdrop — a floodlit turf receding to a horizon.
 *
 * Three.js earns its place here over CSS because the effect is perspective:
 * the ground has real depth, the camera parallaxes with the pointer, and fog
 * dissolves the far turf into the background. A CSS transform fakes one angle;
 * this holds up at every viewport.
 *
 * It runs on phones too — that is where most people will see it — but on its
 * own terms there: a wider, higher camera so the ground actually reads in
 * portrait, a hard cap on pixel ratio, and no pointer parallax where there is
 * no pointer. It stops rendering the moment the hero scrolls away.
 *
 * It degrades on purpose: no WebGL, reduced motion or a hidden tab and the hero
 * is simply flat ink, which is what it is designed to look like anyway.
 */
import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js';

const host = document.getElementById('hero-canvas');
if (host && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  start(host);
}

function start(host) {
  const INK = 0x0b0f14;
  const PLANE = 420;     // how far the ground extends, in world units (~metres)
  const TILE = 7;        // world size of one turf tile
  const TOUCH = 26;      // half the width between the touchlines
  const PITCH = 64;      // distance between repeats of the pitch markings
  const SPEED = 2.2;     // world units per second, toward the camera

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'low-power' });
  } catch {
    return; // no WebGL — the flat hero is a fine outcome
  }

  // A phone reports a device pixel ratio of 3 and often has the weakest GPU in
  // the room. Rendering a full-bleed scene at 3x is the quickest way to cook a
  // battery for no visible gain, so cap harder when the viewport is narrow.
  const dprCap = () => (window.innerWidth < 768 ? 1.5 : 2);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, dprCap()));
  renderer.setSize(host.clientWidth, host.clientHeight); // also sets the CSS size
  renderer.setClearColor(INK, 0);
  renderer.domElement.style.display = 'block';
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(INK, 16, 105);

  // Portrait is not landscape with a different number. A tall, narrow frame at
  // the desktop camera shows a sliver of ground and a lot of sky, so portrait
  // gets a wider lens, a higher eye line and a lower horizon.
  const view = () => (host.clientWidth < host.clientHeight
    ? { fov: 68, y: 7.2, z: 19, look: 1.4 }
    : { fov: 58, y: 5.5, z: 26, look: 2.4 });

  let v = view();
  const camera = new THREE.PerspectiveCamera(v.fov, host.clientWidth / host.clientHeight, 0.1, 240);
  camera.position.set(0, v.y, v.z);
  camera.lookAt(0, v.look, -30);

  // ── The turf ────────────────────────────────────────────────────────────
  // Anisotropy is the whole game on a ground plane. At this grazing angle,
  // without it the turf shimmers and moirés into mush about twenty metres out
  // — that shimmer is exactly what a cheap 3D floor looks like.
  const maxAniso = renderer.capabilities.getMaxAnisotropy();

  const turf = new THREE.TextureLoader().load('assets/img/turf-tile.webp', () => {
    renderer.render(scene, camera); // the first frame may land before the image does
  });
  turf.wrapS = turf.wrapT = THREE.RepeatWrapping;
  turf.colorSpace = THREE.SRGBColorSpace;
  turf.anisotropy = maxAniso;
  turf.repeat.set(PLANE / TILE, PLANE / TILE);

  const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(PLANE, PLANE),
    new THREE.MeshBasicMaterial({ map: turf, fog: true })
  );
  ground.rotation.x = -Math.PI / 2;
  scene.add(ground);

  // A second pass of the same texture at a finer scale, faint. One tile size
  // repeating across a whole field reads as wallpaper in the mid-distance;
  // two scales beating against each other does not.
  const detail = turf.clone();
  detail.needsUpdate = true;
  detail.anisotropy = maxAniso;
  detail.repeat.set(PLANE / (TILE / 3.5), PLANE / (TILE / 3.5));

  const groundDetail = new THREE.Mesh(
    new THREE.PlaneGeometry(PLANE, PLANE),
    new THREE.MeshBasicMaterial({ map: detail, fog: true, transparent: true, opacity: 0.28 })
  );
  groundDetail.rotation.x = -Math.PI / 2;
  groundDetail.position.y = 0.015;
  scene.add(groundDetail);

  // ── Pitch markings ──────────────────────────────────────────────────────
  // Lines running along the direction of travel are unchanged by it, so the
  // touchlines are drawn once, full length. Everything crossing the direction
  // of travel repeats every PITCH units, and the group wraps by exactly that —
  // so the loop is seamless, the same trick the turf texture uses.
  const marks = new THREE.Group();
  const pts = [];

  pts.push(-TOUCH, 0, -PLANE / 2, -TOUCH, 0, PLANE / 2);
  pts.push( TOUCH, 0, -PLANE / 2,  TOUCH, 0, PLANE / 2);

  for (let z = -PLANE / 2; z <= PLANE / 2; z += PITCH) {
    pts.push(-TOUCH, 0, z, TOUCH, 0, z);          // halfway / goal line
    const R = 8, SEG = 48;                         // centre circle
    for (let i = 0; i < SEG; i++) {
      const a = (i / SEG) * Math.PI * 2, b = ((i + 1) / SEG) * Math.PI * 2;
      pts.push(Math.cos(a) * R, 0, z + Math.sin(a) * R,
               Math.cos(b) * R, 0, z + Math.sin(b) * R);
    }
  }

  const markGeo = new THREE.BufferGeometry();
  markGeo.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
  marks.add(new THREE.LineSegments(markGeo, new THREE.LineBasicMaterial({
    color: 0xffffff, transparent: true, opacity: 0.16, fog: true
  })));
  marks.position.y = 0.03;
  scene.add(marks);

  // ── Motion ──────────────────────────────────────────────────────────────
  // Pointer parallax, eased — the camera leans, it does not snap.
  const target = { x: 0, y: 0 };
  const eased = { x: 0, y: 0 };
  if (window.matchMedia('(pointer: fine)').matches) {
    window.addEventListener('pointermove', (e) => {
      target.x = (e.clientX / window.innerWidth - 0.5) * 2;
      target.y = (e.clientY / window.innerHeight - 0.5) * 2;
    }, { passive: true });
  }

  const onResize = () => {
    v = view(); // a phone rotating counts as a resize, and changes the whole framing
    camera.fov = v.fov;
    camera.aspect = host.clientWidth / host.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, dprCap()));
    renderer.setSize(host.clientWidth, host.clientHeight);
  };
  window.addEventListener('resize', onResize, { passive: true });

  // Only render while the hero is actually on screen and the tab is awake.
  let onScreen = true;
  new IntersectionObserver(([e]) => { onScreen = e.isIntersecting; }, { threshold: 0 }).observe(host);

  // Draw one frame straight away. requestAnimationFrame does not run in a
  // background tab, so without this a page opened in one — or captured for a
  // preview — would show an empty canvas until it is focused.
  renderer.render(scene, camera);

  const clock = new THREE.Clock();
  renderer.setAnimationLoop(() => {
    const dt = Math.min(clock.getDelta(), 0.05); // a backgrounded tab returns a huge delta
    if (!onScreen || document.hidden) return;

    // One unit of texture offset is one tile, so the drift matches the
    // markings in world units and grass and lines travel together.
    const advance = SPEED * dt;
    turf.offset.y += advance / TILE;
    detail.offset.y += advance / (TILE / 3.5);
    marks.position.z = (marks.position.z + advance) % PITCH;

    // Scroll lifts the eye line and drops the horizon, so the ground opens out
    // beneath you as the hero leaves. On a phone, where there is no pointer to
    // parallax against, this is the whole effect.
    const t = Math.min(window.scrollY / (host.clientHeight || 1), 1);

    eased.x += (target.x - eased.x) * 0.04;
    eased.y += (target.y - eased.y) * 0.04;
    camera.position.x = eased.x * 3;
    camera.position.y = v.y - eased.y * 1.2 + t * 3.5;
    camera.lookAt(eased.x * 1.5, v.look - t * 1.8, -30);

    renderer.render(scene, camera);
  });
}
