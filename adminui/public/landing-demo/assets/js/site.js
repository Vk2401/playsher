/* Playsher landing — page behaviour.
   GSAP + ScrollTrigger load from CDN before this file. If either is missing
   the page still reads: the .anim class that hides reveal elements is dropped
   on the way out and everything is simply visible. */
(function () {
  'use strict';

  document.querySelectorAll('[data-year]').forEach(function (el) {
    el.textContent = String(new Date().getFullYear());
  });

  // Nav sits transparent over the dark hero, then turns solid once past it.
  var nav = document.getElementById('nav');
  var flipAt = document.getElementById('nav-flip');
  if (nav) {
    // offsetTop is cached: reading it inside the scroll handler forces a layout
    // on every frame, which on a phone competes with the WebGL hero for the
    // same 16ms. It only changes when the page reflows.
    var flipY = 40;
    var measure = function () { if (flipAt) flipY = flipAt.offsetTop - 80; };
    var onScroll = function () { nav.classList.toggle('is-solid', window.scrollY > flipY); };
    measure();
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', function () { measure(); onScroll(); }, { passive: true });
    window.addEventListener('load', function () { measure(); onScroll(); });
  }

  // A marquee off screen still repaints every frame. Park it until it is in
  // view — the page is long and two of these run at once.
  var marquees = document.querySelectorAll('.marquee');
  if (marquees.length && 'IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { e.target.classList.toggle('is-offscreen', !e.isIntersecting); });
    }, { rootMargin: '100px' });
    marquees.forEach(function (m) { io.observe(m); });
  }

  var animated = document.documentElement.classList.contains('anim');
  var haveGsap = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';

  // document.hidden matters: GSAP animates on requestAnimationFrame, which a
  // background tab never fires — the reveal would stay stuck at opacity 0 for
  // a page opened in a background tab, a preview, or a crawler that does not paint.
  if (!animated || !haveGsap || document.hidden) {
    document.documentElement.classList.remove('anim');
    return;
  }

  gsap.registerPlugin(ScrollTrigger);

  // Hero arrives on load; everything else reveals as it is scrolled into view.
  var heroItems = document.querySelectorAll('[data-hero] [data-animate]');
  gsap.to(heroItems, { opacity: 1, y: 0, duration: 0.9, ease: 'power3.out', stagger: 0.07, delay: 0.15 });

  var rest = Array.prototype.filter.call(
    document.querySelectorAll('[data-animate]'),
    function (el) { return Array.prototype.indexOf.call(heroItems, el) === -1; }
  );
  ScrollTrigger.batch(rest, {
    start: 'top 88%',
    onEnter: function (batch) {
      gsap.to(batch, { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out', stagger: 0.07, overwrite: true });
    }
  });

  // Parallax: each marked element drifts at its own rate across the scroll of
  // its section, so a row of three reads as depth rather than a static row.
  document.querySelectorAll('[data-parallax]').forEach(function (el) {
    var depth = parseFloat(el.dataset.parallax) || 0;
    gsap.fromTo(el, { yPercent: depth * 6 }, {
      yPercent: depth * -6,
      ease: 'none',
      scrollTrigger: { trigger: el.closest('[data-parallax-scope]') || el, start: 'top bottom', end: 'bottom top', scrub: 0.6 }
    });
  });

  // Hero stats count up the first time they are seen. The final value is in
  // the markup, so with no JS the number is simply correct rather than 0.
  document.querySelectorAll('[data-count]').forEach(function (el) {
    var target = parseFloat(el.dataset.count) || 0;
    var suffix = el.dataset.suffix || '';
    var box = { n: 0 };
    ScrollTrigger.create({
      trigger: el, start: 'top 95%', once: true,
      onEnter: function () {
        el.textContent = '0' + suffix;
        gsap.to(box, {
          n: target, duration: 1.5, ease: 'power2.out',
          onUpdate: function () { el.textContent = Math.round(box.n) + suffix; }
        });
      }
    });
  });
})();
