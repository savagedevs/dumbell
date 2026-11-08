import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Resvg} from '@resvg/resvg-js';
import sharp from 'sharp';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const output = path.join(root, 'store-assets');
const source = path.join(output, 'source');
const fonts = path.join(source, 'fonts');
const fontSource = '/Users/kartisharma/.agents/skills/canvas-design/canvas-fonts';
await fs.mkdir(fonts, {recursive: true});
await fs.mkdir(path.join(output, 'phone-screenshots'), {recursive: true});
for (const file of ['InstrumentSans-Bold.ttf', 'InstrumentSans-Regular.ttf', 'InstrumentSans-OFL.txt']) {
  try {
    await fs.access(path.join(fonts, file));
  } catch {
    await fs.copyFile(path.join(fontSource, file), path.join(fonts, file));
  }
}
const fontOptions = {
  fontFiles: [path.join(fonts, 'InstrumentSans-Bold.ttf'), path.join(fonts, 'InstrumentSans-Regular.ttf')],
  loadSystemFonts: false,
  defaultFontFamily: 'Instrument Sans',
};
const xml = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const imageData = async name => 'data:image/png;base64,' + (await fs.readFile(path.join(output, 'raw', `${name}.png`))).toString('base64');
const text = (x, y, value, size, color = '#F5F5EF', weight = 700, extra = '') => `<text x="${x}" y="${y}" font-family="Instrument Sans" font-size="${size}" font-weight="${weight}" fill="${color}" ${extra}>${xml(value)}</text>`;
const page = (width, height, body) => `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`;
const slides = [
  ['01-home', 'Your next rep.', 'Starts here.', 'A clearer place for your training.', 'Home and workout overview'],
  ['02-workout', 'Every set.', 'All in one place.', 'Log reps and weights as you train.', 'Workout logging'],
  ['03-exercises', 'Find your', 'next move.', '701 exercises. Illustrations and form cues.', 'Exercise library'],
  ['04-exercise-details', 'Know the', 'movement.', 'Clear illustrations. Practical instructions.', 'Exercise instructions'],
  ['05-exercise-progress', 'See your', 'strength grow.', 'Explore your weights, reps and volume.', 'Exercise progress'],
  ['06-calendar', 'Make training', 'a habit.', 'Your calendar. Your training days.', 'Training calendar'],
];
async function render(svg, filename, width, height) {
  await fs.writeFile(path.join(source, `${filename}.svg`), svg);
  const png = new Resvg(svg, {font: fontOptions}).render().asPng();
  const target = path.join(output, filename.startsWith('feature') ? `${filename}.png` : `phone-screenshots/${filename}.png`);
  await sharp(png).flatten({background: '#121510'}).removeAlpha().png({compressionLevel: 9}).toFile(target);
  const metadata = await sharp(target).metadata();
  if (metadata.width !== width || metadata.height !== height || metadata.channels !== 3) throw new Error(`Invalid export: ${target}`);
  return target;
}
const files = [];
for (let index = 0; index < slides.length; index++) {
  const [name, line1, line2, subtitle, feature] = slides[index];
  const screenshot = await imageData(name);
  const svg = page(1080, 1920, `
    <defs>
      <clipPath id="screen"><rect x="210" y="492" width="660" height="1320" rx="44"/></clipPath>
      <radialGradient id="glow"><stop stop-color="#D5FF3F" stop-opacity=".085"/><stop offset="1" stop-color="#D5FF3F" stop-opacity="0"/></radialGradient>
    </defs>
    <rect width="1080" height="1920" fill="#121510"/>
    <ellipse cx="540" cy="1340" rx="730" ry="660" fill="url(#glow)"/>
    <rect x="76" y="68" width="7" height="37" rx="3.5" fill="#D5FF3F"/>
    ${text(99, 98, 'Dumbbell', 36)}
    ${text(1004, 93, 'WORKOUT JOURNAL', 16, '#A8ACA0', 400, 'text-anchor="end" letter-spacing="2"')}
    ${text(76, 222, line1, 94)}
    ${text(76, 323, line2, 94, '#D5FF3F')}
    ${text(79, 390, subtitle, 29, '#B8BDB0', 400)}
    <rect x="196" y="478" width="688" height="1350" rx="60" fill="#080A06" stroke="#454D3C" stroke-width="2"/>
    <rect x="190" y="650" width="6" height="88" rx="3" fill="#454D3C"/>
    <rect x="884" y="710" width="6" height="120" rx="3" fill="#454D3C"/>
    <image x="210" y="492" width="660" height="1320" href="${screenshot}" clip-path="url(#screen)"/>
    <circle cx="540" cy="512" r="8" fill="#060705" stroke="#242A20" stroke-width="2"/>
    ${text(76, 1873, feature, 21, '#A8ACA0', 400)}
    ${text(1004, 1873, `${String(index + 1).padStart(2, '0')} / 06`, 19, '#D5FF3F', 700, 'text-anchor="end" letter-spacing="2"')}
  `);
  files.push(await render(svg, name, 1080, 1920));
}
const workout = await imageData('02-workout');
const feature = page(1024, 500, `
  <defs><clipPath id="feature-screen"><rect x="745" y="54" width="210" height="420" rx="20"/></clipPath></defs>
  <rect width="1024" height="500" fill="#D5FF3F"/>
  ${text(64, 82, 'Dumbbell', 31, '#15190F')}
  ${text(62, 194, 'Your training.', 66, '#15190F')}
  ${text(62, 267, 'In your hands.', 66, '#15190F')}
  ${text(65, 327, 'Log your sets. See your progress.', 24, '#414B29', 400)}
  <line x1="65" y1="373" x2="563" y2="373" stroke="#15190F" stroke-opacity=".2"/>
  ${text(65, 414, 'WORKOUTS  /  PROGRESS  /  OFFLINE', 16, '#414B29', 700, 'letter-spacing="1.5"')}
  <g transform="rotate(7 850 264)">
    <rect x="736" y="44" width="228" height="440" rx="30" fill="#10130D" stroke="#4E5A35" stroke-width="2"/>
    <image x="745" y="54" width="210" height="420" href="${workout}" clip-path="url(#feature-screen)"/>
    <circle cx="850" cy="61" r="3" fill="#030402"/>
  </g>
`);
await render(feature, 'feature-graphic-1024x500', 1024, 500);
const thumbs = await Promise.all(files.map(async (file, index) => ({
  input: await sharp(file).resize(324, 576).toBuffer(),
  left: 24 + (index % 3) * 348,
  top: 24 + Math.floor(index / 3) * 600,
})));
await sharp({create: {width: 1068, height: 1224, channels: 3, background: '#E8EBE0'}}).composite(thumbs).png().toFile(path.join(output, 'overview.png'));
await fs.writeFile(path.join(output, 'asset-manifest.json'), JSON.stringify({
  app: 'Dumbbell', renderer: 'Flutter UI capture + local SVG composition (Adobe disabled by admin)',
  phoneScreenshots: slides.map(([name, , , , feature]) => ({file: `phone-screenshots/${name}.png`, width: 1080, height: 1920, alt: `Dumbbell: ${feature.toLowerCase()}`})),
  featureGraphic: {file: 'feature-graphic-1024x500.png', width: 1024, height: 500},
  demoData: true,
}, null, 2) + '\n');
console.log('Exported six RGB phone screenshots, feature graphic, overview, and editable SVG sources.');
