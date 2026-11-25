import { writeFileSync } from 'node:fs';

const ease = (x = 0.4, y = 1) => ({ x: [x], y: [y] });
const easeOut = { x: [0.4], y: [1] };
const easeIn = { x: [0.6], y: [0] };

function kf(t, s, e, i = easeOut, o = easeIn) {
  return { t, s, e, i, o };
}

function ellipseLayer({
  ind,
  name,
  w,
  h,
  color,
  dur,
  from,
  to,
  r0 = 0,
  r1 = 0,
  s0 = 100,
  s1 = 100,
  o0 = 70,
  o1 = 35,
}) {
  return {
    ddd: 0,
    ind,
    ty: 4,
    nm: name,
    sr: 1,
    ks: {
      o: {
        a: 1,
        k: [
          kf(0, [o0], [o1]),
          kf(dur / 2, [o1], [o0]),
          { t: dur, s: [o0] },
        ],
      },
      r: {
        a: 1,
        k: [kf(0, [r0], [r1]), { t: dur, s: [r1] }],
      },
      p: {
        a: 1,
        k: [
          kf(0, [...from, 0], [...to, 0]),
          kf(dur / 2, [...to, 0], [...from, 0]),
          { t: dur, s: [...from, 0] },
        ],
      },
      a: { a: 0, k: [0, 0, 0] },
      s: {
        a: 1,
        k: [
          kf(0, [s0, s0, 100], [s1, s1, 100], { x: [0.4, 0.4, 1], y: [1, 1, 1] }, { x: [0.6, 0.6, 0], y: [0, 0, 0] }),
          kf(dur / 2, [s1, s1, 100], [s0, s0, 100], { x: [0.4, 0.4, 1], y: [1, 1, 1] }, { x: [0.6, 0.6, 0], y: [0, 0, 0] }),
          { t: dur, s: [s0, s0, 100] },
        ],
      },
    },
    ao: 0,
    shapes: [
      { ty: 'el', p: { a: 0, k: [0, 0] }, s: { a: 0, k: [w, h] }, nm: 'e' },
      { ty: 'fl', c: { a: 0, k: [...color, 1] }, o: { a: 0, k: 100 }, r: 1, nm: 'f' },
      {
        ty: 'tr',
        p: { a: 0, k: [0, 0] },
        a: { a: 0, k: [0, 0] },
        s: { a: 0, k: [100, 100] },
        r: { a: 0, k: 0 },
        o: { a: 0, k: 100 },
        sk: { a: 0, k: 0 },
        sa: { a: 0, k: 0 },
        nm: 't',
      },
    ],
    ip: 0,
    op: dur,
    st: 0,
    bm: 0,
  };
}

function ringLayer({ ind, name, size, color, dur, from, to, width = 3, o0 = 55, o1 = 18 }) {
  return {
    ddd: 0,
    ind,
    ty: 4,
    nm: name,
    sr: 1,
    ks: {
      o: {
        a: 1,
        k: [kf(0, [o0], [o1]), kf(dur / 2, [o1], [o0]), { t: dur, s: [o0] }],
      },
      r: { a: 1, k: [kf(0, [0], [360]), { t: dur, s: [360] }] },
      p: {
        a: 1,
        k: [
          kf(0, [...from, 0], [...to, 0]),
          kf(dur / 2, [...to, 0], [...from, 0]),
          { t: dur, s: [...from, 0] },
        ],
      },
      a: { a: 0, k: [0, 0, 0] },
      s: { a: 0, k: [100, 100, 100] },
    },
    ao: 0,
    shapes: [
      { ty: 'el', p: { a: 0, k: [0, 0] }, s: { a: 0, k: [size, size] }, nm: 'e' },
      { ty: 'st', c: { a: 0, k: [...color, 1] }, o: { a: 0, k: 100 }, w: { a: 0, k: width }, lc: 2, lj: 1, nm: 's' },
      {
        ty: 'tr',
        p: { a: 0, k: [0, 0] },
        a: { a: 0, k: [0, 0] },
        s: { a: 0, k: [100, 100] },
        r: { a: 0, k: 0 },
        o: { a: 0, k: 100 },
        sk: { a: 0, k: 0 },
        sa: { a: 0, k: 0 },
        nm: 't',
      },
    ],
    ip: 0,
    op: dur,
    st: 0,
    bm: 0,
  };
}

const emerald = [0.0588, 0.4784, 0.2667];
const lime = [0.7804, 0.949, 0.4157];
const sky = [0.2196, 0.7412, 0.9725];
const teal = [0.0784, 0.7216, 0.651];

function write(name, layers, w = 320, h = 320, dur = 300) {
  const doc = {
    v: '5.7.4',
    fr: 30,
    ip: 0,
    op: dur,
    w,
    h,
    nm: name,
    ddd: 0,
    assets: [],
    layers,
  };
  writeFileSync(`assets/lottie/${name}.json`, JSON.stringify(doc));
}

write(
  'aurora',
  [
    ellipseLayer({ ind: 1, name: 'blob1', w: 180, h: 180, color: emerald, dur: 300, from: [96, 104], to: [150, 78], r0: 0, r1: 360, s0: 82, s1: 118, o0: 60, o1: 34 }),
    ellipseLayer({ ind: 2, name: 'blob2', w: 150, h: 150, color: lime, dur: 300, from: [228, 212], to: [188, 250], r0: 360, r1: 0, s0: 100, s1: 74, o0: 42, o1: 26 }),
    ellipseLayer({ ind: 3, name: 'blob3', w: 120, h: 120, color: sky, dur: 240, from: [184, 64], to: [122, 138], r0: 0, r1: 0, s0: 90, s1: 108, o0: 34, o1: 18 }),
  ],
);

write(
  'flow',
  [
    ellipseLayer({ ind: 1, name: 'ribbonA', w: 300, h: 84, color: emerald, dur: 360, from: [170, 92], to: [142, 118], r0: 8, r1: -8, s0: 88, s1: 106, o0: 52, o1: 30 }),
    ellipseLayer({ ind: 2, name: 'ribbonB', w: 260, h: 62, color: lime, dur: 360, from: [126, 206], to: [190, 176], r0: -7, r1: 9, s0: 96, s1: 82, o0: 38, o1: 22 }),
    ellipseLayer({ ind: 3, name: 'ribbonC', w: 210, h: 46, color: sky, dur: 300, from: [196, 152], to: [154, 182], r0: 4, r1: -6, s0: 90, s1: 104, o0: 30, o1: 16 }),
  ],
);

write(
  'drift',
  [
    ellipseLayer({ ind: 1, name: 'dot1', w: 22, h: 22, color: emerald, dur: 240, from: [72, 78], to: [112, 60], r0: 0, r1: 90, s0: 100, s1: 132, o0: 80, o1: 34 }),
    ellipseLayer({ ind: 2, name: 'dot2', w: 14, h: 14, color: lime, dur: 220, from: [232, 92], to: [196, 132], r0: 0, r1: -90, s0: 92, s1: 120, o0: 70, o1: 26 }),
    ellipseLayer({ ind: 3, name: 'dot3', w: 18, h: 18, color: sky, dur: 260, from: [262, 230], to: [218, 258], r0: 0, r1: 120, s0: 88, s1: 116, o0: 64, o1: 22 }),
    ellipseLayer({ ind: 4, name: 'dot4', w: 11, h: 11, color: teal, dur: 200, from: [92, 236], to: [140, 214], r0: 0, r1: 60, s0: 100, s1: 140, o0: 60, o1: 20 }),
  ],
);

write('halo', [
  ringLayer({ ind: 1, name: 'ringA', size: 210, color: emerald, dur: 360, from: [196, 128], to: [166, 160], width: 2, o0: 52, o1: 16 }),
  ringLayer({ ind: 2, name: 'ringB', size: 148, color: lime, dur: 300, from: [122, 194], to: [158, 168], width: 3, o0: 44, o1: 14 }),
  ellipseLayer({ ind: 3, name: 'core', w: 78, h: 78, color: teal, dur: 240, from: [160, 160], to: [174, 146], r0: 0, r1: 180, s0: 90, s1: 112, o0: 26, o1: 14 }),
]);

console.log('generated');
