const fs = require("fs");
const path = require("path");
const pdf = require("../../pdf-parse-1.1.4/package/index.js");

const SERIES_DIR = path.resolve("C:\\Users\\Dr. Yogesh\\Downloads\\SFG- 2026 - Level 1 codex\\test series\\Forum\\GS Simulator Forum 2026");
const IMPORTS_DIR = path.resolve("C:\\Users\\Dr. Yogesh\\Downloads\\SFG- 2026 - Level 1 codex\\upsc-vault-test-v1\\src\\data\\imports");
const TEST_NUMBERS = [1, 2, 3, 4];

const HEADER_PATTERNS = [
  /^PTS 2026 \| Test Code:/i,
  /^Forum Learning Centre:/i,
  /^9311740400,/i,
  /academy\.forumias\.com/i,
  /admissions@forumias\.academy/i,
  /helpdesk@forumias\.academy/i,
  /^Page \d+/i,
  /^\[\d+\]\s*$/,
  /^TEST BOOKLET$/i,
  /^GENERAL STUDIES$/i,
  /^PAPER - I$/i,
  /^I N S T R U C T I O N S$/i,
  /^Canal Road, Patna,/i,
  /^Time Allowed:/i,
  /^T\.B\.C\./i,
  /^A\s*$/,
  /^Name:/i,
  /^Email Id:/i,
  /^Mobile No:/i,
];

function decode(text) {
  return text
    .replace(/â€™/g, "’")
    .replace(/â€˜/g, "‘")
    .replace(/â€œ/g, "“")
    .replace(/â€/g, "”")
    .replace(/â€“/g, "–")
    .replace(/â€”/g, "—")
    .replace(/â€¢/g, "•")
    .replace(/â†’/g, "→")
    .replace(/â‰¥/g, "≥")
    .replace(/â‰¤/g, "≤")
    .replace(/âˆ’/g, "−")
    .replace(/Ã—/g, "×")
    .replace(/Ã·/g, "÷")
    .replace(/Â/g, "")
    .replace(/â‚/g, "₁")
    .replace(/â‚‚/g, "₂")
    .replace(/â‚ƒ/g, "₃")
    .replace(/â‚„/g, "₄")
    .replace(/â‚…/g, "₅")
    .replace(/â‚†/g, "₆")
    .replace(/â‚‡/g, "₇")
    .replace(/â‚ˆ/g, "₈")
    .replace(/â‚‰/g, "₉");
}

function cleanLine(line) {
  return decode(line).replace(/\u00ad/g, "").replace(/\s+/g, " ").trim();
}

function normalize(text) {
  return decode(text).replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

async function extractPdfText(filePath) {
  const buffer = fs.readFileSync(filePath);
  const result = await pdf(buffer);
  return normalize(result.text);
}

function parseQpQuestions(text, bilingual) {
  const lines = normalize(text).split("\n").map(cleanLine).filter((line) => {
    if (!line) return false;
    if (bilingual && /[\u0900-\u097F]/.test(line)) return false;
    return true;
  });
  const questions = new Map();
  let current = null;

  for (const line of lines) {
    if (HEADER_PATTERNS.some((pattern) => pattern.test(line))) continue;
    const qMatch = line.match(/^Q\.(\d+)\)\s*(.*)$/);
    if (qMatch) {
      const qNum = Number(qMatch[1]);
      current = {
        number: qNum,
        lines: [qMatch[2]].filter(Boolean),
      };
      questions.set(qNum, current);
      continue;
    }
    if (!current) continue;
    current.lines.push(line);
  }
  return questions;
}

function parseSolQuestions(text) {
  const lines = normalize(text).split("\n").map(cleanLine).filter((line) => line && !HEADER_PATTERNS.some((p) => p.test(line)));
  const questions = [];
  let current = null;
  let state = "idle";

  for (const line of lines) {
    const qMatch = line.match(/^Q\.(\d+)\)\s*(.*)$/);
    if (qMatch) {
      if (current) questions.push(current);
      current = {
        number: Number(qMatch[1]),
        explanationLines: [],
        sourceLines: [],
        rawSubject: "",
        rawTopic: "",
        rawSubtopic: "",
        answer: "",
      };
      state = "question";
      continue;
    }
    if (!current) continue;
    if (/^Ans(?::?\)|:)\s*/i.test(line)) {
      current.answer = ((line.match(/^Ans(?::?\)|:)\s*([a-d])/i) || [null, ""])[1] || "").toLowerCase();
      state = "answer";
      continue;
    }
    if (/^Exp(?::?\)|:)\s*/i.test(line)) {
      current.explanationLines.push(line.replace(/^Exp(?::?\)|:)\s*/i, "").trim());
      state = "explanation";
      continue;
    }
    if (/^Source(?::?\)|:)\s*/i.test(line)) {
      current.sourceLines.push(line.replace(/^Source(?::?\)|:)\s*/i, "").trim());
      state = "source";
      continue;
    }
    if (/^Subject(?::?\)|:)\s*/i.test(line)) {
      current.rawSubject = line.replace(/^Subject(?::?\)|:)\s*/i, "").trim();
      state = "subject";
      continue;
    }
    if (/^Topic(?::?\)|:)\s*/i.test(line)) {
      current.rawTopic = line.replace(/^Topic(?::?\)|:)\s*/i, "").trim();
      state = "topic";
      continue;
    }
    if (/^Subtopic(?::?\)|:)\s*/i.test(line)) {
      current.rawSubtopic = line.replace(/^Subtopic(?::?\)|:)\s*/i, "").trim();
      state = "subtopic";
      continue;
    }
    if (state === "explanation") {
      current.explanationLines.push(line);
    } else if (state === "source") {
      current.sourceLines.push(line);
    }
  }
  if (current) questions.push(current);
  return questions;
}

function splitQuestionLines(lines) {
  const statementLines = [];
  const options = { a: "", b: "", c: "", d: "" };
  let currentOption = null;

  for (const line of lines.map(cleanLine).filter(Boolean)) {
    const optionMatch = line.match(/^([a-d])\)\s*(.*)$/i);
    if (optionMatch) {
      currentOption = optionMatch[1].toLowerCase();
      options[currentOption] = optionMatch[2].trim();
      continue;
    }
    if (currentOption && !/^Q\.\d+\)/.test(line)) {
      options[currentOption] = `${options[currentOption]} ${line}`.trim();
    } else {
      currentOption = null;
      statementLines.push(line);
    }
  }
  return { statementLines, options };
}

function parsePyqMeta(sourceText) {
  let match = (sourceText || "").match(/UPSC\s+CSE\s+(?:Pre|Prelims?)\s+(\d{4})/i);
  if (match) return { isPyq: true, pyqMeta: { group: "UPSC CSE", exam: "Prelims", year: Number(match[1]) } };
  match = (sourceText || "").match(/UPSC\s+CAPF\s+(\d{4})/i);
  if (match) return { isPyq: true, pyqMeta: { group: "UPSC CAPF", exam: "CAPF", year: Number(match[1]) } };
  match = (sourceText || "").match(/UPSC\s+CDS\s*(I|II)?\s*(\d{4})/i);
  if (match) return { isPyq: true, pyqMeta: { group: "UPSC CDS", exam: match[1] ? `CDS ${match[1].toUpperCase()}` : "CDS", year: Number(match[2]) } };
  return { isPyq: false, pyqMeta: null };
}

function mapPolity(topic, h) {
  if (/election commission|political part|election symbol/.test(topic) || /election commission|political part|election symbol/.test(h)) return ["Polity", null, "Elections, Political Parties, Anti-Defection Law"];
  if (/post independence/.test(topic) && /chief minister|prime minister/.test(h)) return ["Polity", null, "Governance and Policies"];
  if (/directive principles|dpsp/.test(topic) || /directive principles|dpsp/.test(h)) return ["Polity", null, "Directive Principles of State Policy DPSP"];
  if (/fundamental rights|article 32|article 21|article 14/.test(h)) return ["Polity", null, "Fundamental Rights"];
  if (/preamble/.test(h)) return ["Polity", null, "Preamble"];
  if (/language|eighth schedule/.test(h)) return ["Polity", null, "Language"];
  if (/tribunal|constitutional body|pac|motion of thanks|parliament|whip|legislature/.test(h)) return ["Polity", null, "Parliament Procedures, Proceedings, Officers, Bills, Committees, Houses, etc."];
  if (/tribal area|sixth schedule/.test(h)) return ["Polity", null, "Scheduled and Tribal Areas"];
  if (/governor|president|vice president/.test(h)) return ["Polity", null, "President, Vice President, Governor"];
  if (/amendment|basic structure|constitution/.test(h)) return ["Polity", null, "Amendment and Basic Structure"];
  return ["Polity", null, topic.includes("local") ? "Local Government Panchayats, Municipalities, Cooperative Societies" : "Governance and Policies"];
}

function mapHistory(topic, h) {
  if (/literature/.test(topic)) {
    if (/harshacharita|rajatarangini|kavirajamarga|samarangana/.test(h)) return ["History", "Medieval", "Medieval Literature & Books"];
    return ["History", "Art & Culture", "Literature"];
  }
  if (/sangam|ashoka|maurya|buddh|jain|indus|vedic|shreni|ettutokai|pattuppattu/.test(h)) {
    if (/ashoka|maurya/.test(h)) return ["History", "Ancient", "Mauryan Empire"];
    if (/buddh|jain|pratityasamutpada/.test(h)) return ["History", "Ancient", "Buddhism, Jainism & Other Philosophies"];
    if (/sangam|ettutokai|pattuppattu/.test(h)) return ["History", "Ancient", "Sangam Age"];
    if (/indus|sutkagen|alamgirpur/.test(h)) return ["History", "Ancient", "Indus Valley Civilization"];
    return ["History", "Ancient", "Literature of Ancient India"];
  }
  if (/ghori|delhi sultanate|bahmani|mahmud gawan|rajatarangini|prithviraj|zain-ul-abidin/.test(h)) {
    if (/bahmani|vijayanagara/.test(h)) return ["History", "Medieval", "Vijayanagara Empire & Bahmani Kingdom"];
    if (/ghori|delhi sultanate/.test(h)) return ["History", "Medieval", "Delhi Sultanate & Early Muslim Invasions"];
    return ["History", "Medieval", "Major Dynasties of Early Medieval India"];
  }
  if (/wood[’']?s education|freedom movement|national movement|governor general|revolt/.test(h)) {
    if (/wood/.test(h)) return ["History", "Modern", "Development of Press, Education"];
    return ["History", "Modern", "Gandhian Phase (Post-1917 till Partition, including NCM, CDM, QIM, Simon Commission, etc.)"];
  }
  if (/basavanna|sanskrit|manuscript|philosophy|archaeological site/.test(h)) return ["History", "Art & Culture", /philosophy|basavanna/.test(h) ? "Religion & Philosophy" : "Literature"];
  return ["History", "Modern", "Advent of Europeans, British Expansion, Anglo Wars"];
}

function mapGeography(topic, h) {
  if (/tide|ocean|uncclos|salinity|currents/.test(h)) return ["Geography", "Physical Geography - Oceanography", /currents/.test(h) ? "Ocean Currents" : "Movement of Ocean Water (Tides, Waves, etc.)"];
  if (/himalayan|coastal plains|itcz|climate|monsoon|pressure|wind|rainfall/.test(h)) return ["Geography", /monsoon|climate/.test(h) ? "Indian Geography" : "Physical Geography - Climatology", /monsoon|climate/.test(h) ? "Climate, Monsoon" : "Pressure, Winds, Airmasses (Coriolis Force, Frictional Force, etc.)"];
  if (/planetary boundary|rock|earthquake|plateau|mountain|volcano/.test(h)) return ["Geography", "Physical Geography - Geomorphology", /earthquake|volcano/.test(h) ? "Earthquake and Volcanism" : "Mountains and Plateaus"];
  if (/population census|migration|tribe/.test(h)) return ["Geography", "Human Geography", /tribe/.test(h) ? "Tribes" : "Demography, Population, Census (Literacy, Sex Ratio, etc.)"];
  if (/country|strait|sea|gulf|port|trade route/.test(h)) return ["Geography", "World Geography", "Straits, Channels, Oceans, Seas, Gulfs, Bays"];
  return ["Geography", "Indian Geography", "Physiography of India (Location, Division, Physiographic Regions)"];
}

function mapEnvironment(topic, h) {
  if (/tiger reserve|biosphere|ramsar|sanctuary|national park/.test(h)) return ["Environment", "Protected Area Network", /tiger/.test(h) ? "Tiger Reserve, Elephant Reserve, other species-specific reserves, etc." : "National Park, Wildlife Sanctuary, Biosphere Reserve"];
  if (/biodiversity|species|fauna|coral bleaching|ecology|ecosystem/.test(h)) return ["Environment", "Ecology & Ecosystem", /coral/.test(h) ? "Aquatic Ecosystem and Life (Aquatic Ecosystem, Maritime Zones, Corals, Mangrove, Marine Vegetation)" : "Ecology and Ecosystem"];
  if (/climate change|carbon|cop|united nations ocean conference|global carbon/.test(h)) return ["Environment", /unfccc|conference|cop/.test(h) ? "International Environmental Conventions, Organisations & Laws" : "Climate Change", /conference|cop/.test(h) ? "Climate Change (UNFCCC, UNEP, REDD, etc.)" : "Climate Change and Impacts of Climate Change over Earth"];
  if (/pollution|air act|water act|plastic|e-waste/.test(h)) return ["Environment", "Environmental Pollution & Pollutants", /plastic/.test(h) ? "Plastics and Microplastics" : "Air, Water, Noise Pollution, SLCPs, etc."];
  return ["Environment", "Biodiversity & Conservation", "Major Species (Keystone, Indicator, Invasive, Endemic, etc.)"];
}

function mapEconomy(topic, h) {
  if (/monetary policy|repo|rbi|stablecoin|ppi|payments/.test(h)) return ["Economy", "Money, Banking, Finance, Insurance", /stablecoin/.test(h) ? "Money (Evolution, Types, Digital Currency, Crypto, etc.)" : "Monetary Policy"];
  if (/budget|fiscal|tax|cbdt|direct taxes|board of direct taxes/.test(h)) return ["Economy", "Fiscal Policy, Budget, Taxation", /tax/.test(h) ? "Taxation" : "Fiscal Policy"];
  if (/inflation|gdp|national income|fiscal policy/.test(h)) return ["Economy", "Sectors of Economy", "GDP, Inflation, Unemployment"];
  if (/trade|wto|imf|world bank|ndb|export|import/.test(h)) return ["Economy", "External Sector", /wto|imf|world bank|ndb/.test(h) ? "International Organisations (WTO, IMF, World Bank, RCEP, FTAs, etc.)" : "Trade (Exports, Imports, FDI, FII, etc.)"];
  if (/gold|energy|aviation fuel|transport/.test(h)) return ["Economy", "Infrastructure", /transport|aviation/.test(h) ? "Transport" : "Energy"];
  return ["Economy", "Money, Banking, Finance, Insurance", "Banking, NPA"];
}

function mapScience(topic, h) {
  if (/satellite|planetary|space|isro/.test(h)) return ["Science & Technology", null, "Space"];
  if (/digital|robot|ai|technology|ppi/.test(h)) return ["Science & Technology", null, "Information and Communication Technology, Robotics, AI"];
  if (/nuclear|radiation/.test(h)) return ["Science & Technology", null, "Nuclear Technology"];
  return ["Science & Technology", null, "Biology and Biotechnology"];
}

function mapIR(topic, h) {
  if (/quad|brics|un|summit|conference/.test(h)) return ["International Relations", null, "Current Affairs Focus (Summits, Reports, Conflicts, Visits, etc.)"];
  if (/usa|united states|israel|ukraine|china|pakistan|neighbourhood/.test(h)) return ["International Relations", null, /china|pakistan|nepal|sri lanka/.test(h) ? "India and Neighbourhood (Pakistan, China, Nepal, Sri Lanka, etc.)" : "India and the World (USA, Russia, Middle East, Africa, etc.)"];
  return ["International Relations", null, "International Organizations (UN, IMF, World Bank, ASEAN, BRICS, etc.)"];
}

function classify(rawSubject, rawTopic, questionText, explanationText) {
  const subject = (rawSubject || "").toLowerCase();
  const topic = (rawTopic || "").toLowerCase();
  const h = `${subject} ${topic} ${questionText} ${explanationText}`.toLowerCase();
  if (/indian polity/.test(h)) return mapPolity(topic, h);
  if (/indian history|ancient indian history|medieval indian history|modern indian history/.test(h)) return mapHistory(topic, h);
  if (subject.includes("polity") || topic.includes("polity") || topic.includes("legislature") || topic.includes("fundamental rights")) return mapPolity(topic, h);
  if (subject.includes("history") || topic.includes("ancient") || topic.includes("medieval") || topic.includes("modern") || topic.includes("art and culture")) return mapHistory(topic, h);
  if (subject.includes("geography") || topic.includes("geography")) return mapGeography(topic, h);
  if (subject.includes("environment") || topic.includes("environment") || topic.includes("biodiversity")) return mapEnvironment(topic, h);
  if (subject.includes("economy") || topic.includes("economy") || topic.includes("monetary") || topic.includes("inflation")) return mapEconomy(topic, h);
  if (subject.includes("science") || topic.includes("science")) return mapScience(topic, h);
  if (subject.includes("international relations") || topic.includes("international")) return mapIR(topic, h);
  if (subject.includes("current affairs")) {
    if (topic.includes("polity")) return mapPolity(topic, h);
    if (topic.includes("economy")) return mapEconomy(topic, h);
    if (topic.includes("environment")) return mapEnvironment(topic, h);
    if (topic.includes("history")) return mapHistory(topic, h);
    if (topic.includes("science")) return mapScience(topic, h);
    if (topic.includes("international")) return mapIR(topic, h);
  }
  return mapIR(topic, h);
}

function maybeBuildQuestionTable(statementLines) {
  return { questionBlocks: null, questionTable: null };
}

function buildQuestion(testId, qpQuestion, solQuestion) {
  if (!qpQuestion) return null;
  const split = splitQuestionLines(qpQuestion.lines);
  const statementLines = split.statementLines;
  const questionText = statementLines.join(" ").replace(/\s+/g, " ").trim();
  const explanationText = solQuestion.explanationLines.join(" ");
  const [subject, sectionGroup, microTopic] = classify(solQuestion.rawSubject, solQuestion.rawTopic, questionText, explanationText);
  const pyq = parsePyqMeta(solQuestion.sourceLines.join(" "));
  const tableBits = maybeBuildQuestionTable(statementLines);
  return {
    id: `${testId}-q${String(qpQuestion.number).padStart(2, "0")}`,
    questionNumber: qpQuestion.number,
    subject,
    sectionGroup,
    microTopic,
    originalSourceTopic: solQuestion.rawTopic || microTopic,
    isPyq: pyq.isPyq,
    pyqMeta: pyq.pyqMeta,
    questionTypeTags: [],
    statementLines,
    questionText,
    options: split.options,
    correctAnswer: solQuestion.answer,
    explanationMarkdown: `**Exp) Option ${solQuestion.answer} is the correct answer.**\n${solQuestion.explanationLines.join("\n")}`.trim(),
    source: {
      sourceText: solQuestion.sourceLines.join(" "),
      subject,
      topic: solQuestion.rawTopic || "",
      subtopic: solQuestion.rawSubtopic || "",
    },
    questionBlocks: tableBits.questionBlocks,
    questionTable: tableBits.questionTable,
  };
}

async function buildTest(testNumber) {
  const qpName = fs.readdirSync(SERIES_DIR).find((name) => new RegExp(`^Test ${testNumber} QP`, "i").test(name));
  const solName = fs.readdirSync(SERIES_DIR).find((name) => new RegExp(`^Test ${testNumber} SOL`, "i").test(name) && !/Hindi/i.test(name));
  const qpQuestions = parseQpQuestions(await extractPdfText(path.join(SERIES_DIR, qpName)), /ENG Hindi/i.test(qpName));
  const solQuestions = parseSolQuestions(await extractPdfText(path.join(SERIES_DIR, solName)));
  const testId = `forum-gs-simulator-2026-test${testNumber}`;
  const questions = solQuestions.map((solQuestion) => buildQuestion(testId, qpQuestions.get(solQuestion.number), solQuestion)).filter(Boolean);
  return {
    id: testId,
    title: `Forum GS Simulator 2026 • Test ${testNumber}`,
    provider: "Forum GS Simulator 2026",
    series: "GS Simulator",
    level: "Full Test",
    year: 2026,
    subject: "General Studies",
    sectionGroup: null,
    paperType: "Full Length",
    defaultMinutes: 120,
    sourceMode: "qp-sol",
    questions,
  };
}

async function main() {
  for (const testNumber of TEST_NUMBERS) {
    const json = await buildTest(testNumber);
    const outPath = path.join(IMPORTS_DIR, `${json.id}.json`);
    fs.writeFileSync(outPath, JSON.stringify(json, null, 2) + "\n", "utf8");
    console.log(`WROTE ${outPath} (${json.questions.length} questions)`);
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
