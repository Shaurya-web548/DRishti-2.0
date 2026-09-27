// Small builders over the docx library so build_report.js reads like the
// report it produces. Colours and fonts follow the DRishti web app.

const fs = require('fs');
const {
  Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType,
  ShadingType, BorderStyle, AlignmentType, ImageRun, PageBreak,
} = require('docx');

const INK = '0F2A1F';
const MOSS = '4F8C6D';
const AMBER = 'E6A53A';
const MUTED = '5E6E65';
const LINE = 'D9E2DC';
const PAGE_CONTENT_DXA = 9026;           // A4 minus two 1-inch margins
const PAGE_CONTENT_PX = 600;

let figureNo = 0;
let tableNo = 0;

/* ------------------------------------------------------------------ text */

// Accepts a string, or an array mixing strings and {text, bold, italics,
// code, fill} objects. `fill` marks a blank the team still has to complete.
function runs(content, base = {}) {
  const parts = Array.isArray(content) ? content : [content];
  return parts.map((p) => {
    if (typeof p === 'string') return new TextRun({ text: p, ...base });
    const opts = { ...base, text: p.text, bold: p.bold ?? base.bold, italics: p.italics ?? base.italics };
    if (p.code) Object.assign(opts, { font: 'Consolas', size: 19, color: '1F4436' });
    if (p.fill) Object.assign(opts, { highlight: 'yellow' });
    if (p.color) opts.color = p.color;
    return new TextRun(opts);
  });
}

const p = (content, opts = {}) => new Paragraph({
  children: runs(content),
  spacing: { before: 80, after: 140, line: 300 },
  alignment: opts.align || AlignmentType.JUSTIFIED,
  ...opts.paragraph,
});

const lead = (content) => new Paragraph({
  children: runs(content, { size: 24, color: '33443A' }),
  spacing: { after: 200, line: 320 },
});

const h1 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(text)], pageBreakBefore: true });
const h2 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(text)] });
const h3 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(text)] });

const bullets = (items, ref = 'bullets') => items.map((it) => new Paragraph({
  numbering: { reference: ref, level: 0 },
  children: runs(it),
  spacing: { after: 80, line: 290 },
}));

const numbered = (items) => bullets(items, 'numbers');

const pageBreak = () => new Paragraph({ children: [new PageBreak()] });

/* ---------------------------------------------------------------- tables */

function cell(content, width, { header = false, align = AlignmentType.LEFT, fill } = {}) {
  return new TableCell({
    width: { size: width, type: WidthType.DXA },
    shading: header ? { fill: INK, type: ShadingType.CLEAR, color: 'auto' }
      : fill ? { fill, type: ShadingType.CLEAR, color: 'auto' } : undefined,
    margins: { top: 70, bottom: 70, left: 110, right: 110 },
    children: [new Paragraph({
      alignment: align,
      children: runs(content, header ? { bold: true, color: 'FFFFFF', size: 19 } : { size: 19 }),
    })],
  });
}

// widths are fractions of the page width; numeric columns right-aligned.
function table(headers, rows, fractions, { numeric = [], caption, highlightRow } = {}) {
  const isNum = (i) => numeric.includes(i);
  const widths = fractions.map((f) => Math.round(f * PAGE_CONTENT_DXA));
  widths[widths.length - 1] += PAGE_CONTENT_DXA - widths.reduce((a, b) => a + b, 0);
  const border = { style: BorderStyle.SINGLE, size: 4, color: LINE };
  const out = [];
  if (caption) {
    tableNo += 1;
    out.push(new Paragraph({
      keepNext: true,
      spacing: { before: 120, after: 80 },
      children: runs([{ text: `Table ${tableNo}. `, bold: true }, caption], { size: 19, color: MUTED }),
    }));
  }
  out.push(new Table({
    width: { size: PAGE_CONTENT_DXA, type: WidthType.DXA },
    columnWidths: widths,
    borders: { top: border, bottom: border, left: border, right: border, insideHorizontal: border, insideVertical: border },
    rows: [
      new TableRow({
        tableHeader: true,
        cantSplit: true,
        children: headers.map((h, i) => cell(h, widths[i], {
          header: true, align: isNum(i) ? AlignmentType.RIGHT : AlignmentType.LEFT,
        })),
      }),
      ...rows.map((r, ri) => new TableRow({
        cantSplit: true,
        children: r.map((c, i) => cell(c, widths[i], {
          align: isNum(i) ? AlignmentType.RIGHT : AlignmentType.LEFT,
          fill: highlightRow === ri ? 'FBF1DD' : ri % 2 ? 'F6F8F6' : undefined,
        })),
      })),
    ],
  }));
  return out;
}

// A shaded box with an amber rule down the left: key findings, cautions.
function callout(title, body, colour = AMBER) {
  const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
  const bodyParas = (Array.isArray(body) ? body : [body]).map((b) => new Paragraph({
    spacing: { after: 60, line: 290 },
    children: runs(b, { size: 21 }),
  }));
  return [new Table({
    width: { size: PAGE_CONTENT_DXA, type: WidthType.DXA },
    columnWidths: [PAGE_CONTENT_DXA],
    borders: { top: none, bottom: none, right: none, insideHorizontal: none, insideVertical: none,
               left: { style: BorderStyle.SINGLE, size: 36, color: colour } },
    rows: [new TableRow({ cantSplit: true, children: [new TableCell({
      width: { size: PAGE_CONTENT_DXA, type: WidthType.DXA },
      shading: { fill: 'F3F7F4', type: ShadingType.CLEAR, color: 'auto' },
      margins: { top: 140, bottom: 120, left: 220, right: 220 },
      children: [new Paragraph({ spacing: { after: 80 }, children: runs(title, { bold: true, color: INK, size: 22 }) }), ...bodyParas],
    })] })],
  })];
}

/* --------------------------------------------------------------- figures */

function pngSize(buf) {
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

function figure(file, caption, widthPx = PAGE_CONTENT_PX) {
  const data = fs.readFileSync(file);
  const { w, h } = pngSize(data);
  figureNo += 1;
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      keepNext: true,
      spacing: { before: 120, after: 60 },
      children: [new ImageRun({ type: 'png', data, transformation: { width: widthPx, height: Math.round((widthPx * h) / w) } })],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 220 },
      children: runs([{ text: `Figure ${figureNo}. `, bold: true }, caption], { size: 19, color: MUTED, italics: true }),
    }),
  ];
}

module.exports = {
  INK, MOSS, AMBER, MUTED, PAGE_CONTENT_DXA,
  runs, p, lead, h1, h2, h3, bullets, numbered, pageBreak, table, callout, figure,
};
