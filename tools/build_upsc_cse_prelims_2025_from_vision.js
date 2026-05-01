const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const APP_ROOT = path.resolve(__dirname, "..");
const INPUT_PATH = path.join(ROOT, "vision-upsc-2025-paper.txt");
const OUTPUT_JSON = path.join(APP_ROOT, "src", "data", "imports", "upsc-cse-prelims-2025-gs-paper-1.json");

const KNOWN_SECTIONS = [
  "S&T",
  "Current Affairs (S&T)",
  "Environment & Ecology",
  "Current Affairs (Environment)",
  "Economy",
  "Current Affairs (Economy)",
  "Polity & Governance",
  "Current Affairs (Polity & Governance)",
  "Ancient History",
  "Medieval History",
  "Modern History",
  "Art and Culture",
  "Current Affairs (History)",
  "Geography",
  "Current Affairs (Geography)",
  "International Relations",
  "Current Affairs (IR)",
  "Current Affairs",
  "Miscellaneous"
];

const SECTION_GROUP_BY_SUBJECT_TOPIC = new Map([
  ["Environment|Ecology and Ecosystem", "Ecology & Ecosystem"],
  ["Environment|Mass Extinctions and IUCN Red List", "Biodiversity & Conservation"],
  ["Environment|Wildlife Conservation (Tiger, Elephant, Lion, Rhino, Crocodile, Vulture, Tortoise, Dolphin, etc.)", "Biodiversity & Conservation"],
  ["Environment|Ramsar Sites, World Heritage Sites, UNESCO Heritage Sites, WHS, Biodiversity Heritage Sites, etc.", "Protected Area Network"],
  ["Environment|Tiger Reserve, Elephant Reserve, other species-specific reserves, etc.", "Protected Area Network"],
  ["Environment|Climate Change and Impacts of Climate Change over Earth", "Climate Change"],
  ["Environment|Greenhouse Gases (GHG), ODS, Related Terms, Global Warming", "Climate Change"],
  ["Environment|Air, Water, Noise Pollution, SLCPs, etc.", "Environmental Pollution & Pollutants"],
  ["Environment|EPA Act, EIA, ESZ, CRZ", "Indian Government Laws & Organisations"],

  ["Economy|Budget", "Fiscal Policy, Budget, Taxation"],
  ["Economy|Taxation", "Fiscal Policy, Budget, Taxation"],
  ["Economy|Fiscal Policy", "Fiscal Policy, Budget, Taxation"],
  ["Economy|Monetary Policy", "Money, Banking, Finance, Insurance"],
  ["Economy|Banking, NPA", "Money, Banking, Finance, Insurance"],
  ["Economy|Financial Markets", "Money, Banking, Finance, Insurance"],
  ["Economy|Insurance and Pension", "Money, Banking, Finance, Insurance"],
  ["Economy|Trade (Exports, Imports, FDI, FII, etc.)", "External Sector"],
  ["Economy|International Organisations (WTO, IMF, World Bank, RCEP, FTAs, etc.)", "External Sector"],
  ["Economy|GDP, Inflation, Unemployment", "Sectors of Economy"],
  ["Economy|Agriculture (Schemes, APMC, MSP, Exports, etc.)", "Sectors of Economy"],
  ["Economy|Energy", "Infrastructure"],
  ["Economy|Transport", "Infrastructure"],

  ["Geography|Earthquake and Volcanism", "Physical Geography - Geomorphology"],
  ["Geography|Geology and Rocks", "Physical Geography - Geomorphology"],
  ["Geography|Landforms", "Physical Geography - Geomorphology"],
  ["Geography|Atmosphere (Composition, Structure)", "Physical Geography - Climatology"],
  ["Geography|Pressure, Winds, Airmasses (Coriolis Force, Frictional Force, etc.)", "Physical Geography - Climatology"],
  ["Geography|Cyclones", "Physical Geography - Climatology"],
  ["Geography|El Nino and La Nina", "Physical Geography - Climatology"],
  ["Geography|Climate, Monsoon", "Indian Geography"],
  ["Geography|Drainage System, Rivers, River Interlinking", "Indian Geography"],
  ["Geography|Soils of India", "Indian Geography"],
  ["Geography|Natural Vegetation (Forests, Trees, Vegetation)", "Indian Geography"],
  ["Geography|Physiography of India (Location, Division, Physiographic Regions)", "Indian Geography"],
  ["Geography|Ocean Currents", "Physical Geography - Oceanography"],
  ["Geography|Movement of Ocean Water (Tides, Waves, etc.)", "Physical Geography - Oceanography"],
  ["Geography|Straits, Channels, Oceans, Seas, Gulfs, Bays", "World Geography"],
  ["Geography|Major Ports, Trade Routes", "World Geography"]
]);

function slug(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}

function normalizeText(value) {
  return String(value || "")
    .replace(/\u00a0/g, " ")
    .replace(/â€”/g, "—")
    .replace(/â€“/g, "–")
    .replace(/â€˜/g, "'")
    .replace(/â€™/g, "'")
    .replace(/â€œ/g, '"')
    .replace(/â€/g, '"')
    .replace(/â€¢/g, "•")
    .replace(/Â©/g, "©")
    .replace(/Â/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\s+\n/g, "\n")
    .trim();
}

function cleanLine(value) {
  return normalizeText(value).replace(/\s+/g, " ").trim();
}

function isPageNoise(line) {
  return !line
    || /^www\.visionias\.in$/i.test(line)
    || /^https?:\/\/visionias\.in/i.test(line)
    || /^©\s*Vision IAS$/i.test(line)
    || /^\d+\s+www\.visionias\.in/i.test(line)
    || /^Q\.N\.$/i.test(line)
    || /^Questions$/i.test(line)
    || /^A\s*ns\s*w\s*er$/i.test(line)
    || /^Explanation$/i.test(line)
    || /^Motivation$/i.test(line)
    || /^Current Affairs$/i.test(line)
    || /^Le\s*vel$/i.test(line)
    || /^Nat\s*ure$/i.test(line)
    || /^Source$/i.test(line)
    || /^Ty\s*pe$/i.test(line)
    || /^VisionIAS Test$/i.test(line)
    || /^Series\/Sandhan\/PT$/i.test(line)
    || /^365\/Open Test\/Abhyaas$/i.test(line);
}

function isQuestionStart(line, expected) {
  const match = line.match(/^(\d{1,3})\s+(.+)$/);
  if (!match) return false;
  const number = Number(match[1]);
  if (number !== expected) return false;
  return !/www\.visionias\.in/i.test(match[2]);
}

function splitSection(lines) {
  const first = lines[0].match(/^(\d{1,3})\s+(.+)$/);
  if (!first) throw new Error(`Invalid question block start: ${lines[0]}`);

  const candidates = [];
  const pieces = [];
  for (let i = 0; i < Math.min(4, lines.length); i += 1) {
    pieces.push(i === 0 ? first[2] : lines[i]);
    const joined = pieces.join(" ").trim();
    candidates.push({ consumed: i + 1, text: joined, slug: slug(joined) });
  }

  for (let i = candidates.length - 1; i >= 0; i -= 1) {
    const candidate = candidates[i];
    const exact = KNOWN_SECTIONS.find((item) => slug(item) === candidate.slug);
    if (exact) {
      return { number: Number(first[1]), section: exact, consumed: candidate.consumed, leadingLine: "" };
    }
  }

  for (const item of KNOWN_SECTIONS) {
    if (first[2].startsWith(item)) {
      return {
        number: Number(first[1]),
        section: item,
        consumed: 1,
        leadingLine: first[2].slice(item.length).trim()
      };
    }
  }

  for (const candidate of candidates) {
    const match = KNOWN_SECTIONS.find((item) => candidate.slug.startsWith(slug(item)));
    if (match) {
      return {
        number: Number(first[1]),
        section: match,
        consumed: candidate.consumed,
        leadingLine: ""
      };
    }
  }

  const fallback = KNOWN_SECTIONS.find((item) => slug(first[2]).startsWith(slug(item)) || slug(item).startsWith(slug(first[2])));
  return {
    number: Number(first[1]),
    section: fallback || first[2],
    consumed: 1,
    leadingLine: fallback && first[2].startsWith(fallback) ? first[2].slice(fallback.length).trim() : ""
  };
}

function normalizeOptionText(value) {
  return normalizeText(value)
    .replace(/\s+/g, " ")
    .replace(/\s+([,.;:?!])/g, "$1")
    .trim();
}

function isLikelyQuestionLine(line) {
  return /^(?:[IVX]+\.\s*|\d+\.\s*|Statement\b|Assertion\b|Reason\b|Select\b|How\b|Which\b|With\b|Consider\b|Match\b|Arrange\b|In\b|Of\b|From\b|To\b|For\b|Do\b|Use\b|Source\b|Are\b|Is\b|Can\b|May\b|The\b|And\b|Given\b|Correct\b)/i.test(line);
}

function cleanQuestionLines(lines) {
  return lines.filter((line) => line
    && !/https?:\/\//i.test(line)
    && !/(?:PT 365|Monthly Current Affairs|News today|Vision IAS|Sandhan)/i.test(line)
    && !/^[EMD]\s+(?:FCA|CAA|CA|FA|F|U)\b/.test(line));
}

function inferQuestionParts(lines) {
  const questionLines = [];
  const options = {};
  let currentOption = null;
  let answer = null;
  const explanationLines = [];
  let sawFourOptions = false;
  let answerSeenBeforeOptions = false;

  let i = 0;
  for (; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line) continue;

    if (!currentOption && !sawFourOptions) {
      const earlyAnswer = line.match(/^([A-D])\s+(.+)$/);
      if (earlyAnswer && questionLines.length >= 1) {
        answer = answer || earlyAnswer[1].toLowerCase();
        answerSeenBeforeOptions = true;
        continue;
      }
    }

    const optionMatch = line.match(/^\(([a-d])\)\s*(.*)$/i);
    if (optionMatch) {
      currentOption = optionMatch[1].toLowerCase();
      options[currentOption] = optionMatch[2] || "";
      sawFourOptions = Object.keys(options).length === 4;
      continue;
    }
    if (currentOption) {
      const nextOption = line.match(/^\(([a-d])\)\s*(.*)$/i);
      const answerMatch = Object.keys(options).length >= 4 ? line.match(/^([A-D])\s+(.*)$/) : null;
      if (nextOption) {
        currentOption = nextOption[1].toLowerCase();
        options[currentOption] = nextOption[2] || "";
        sawFourOptions = Object.keys(options).length === 4;
        continue;
      }
      if (answerMatch) {
        answer = answerMatch[1].toLowerCase();
        if (answerMatch[2]) explanationLines.push(answerMatch[2]);
        i += 1;
        break;
      }
      if (Object.keys(options).length >= 4 && answer) {
        break;
      }
      options[currentOption] = `${options[currentOption]} ${line}`.trim();
      continue;
    }

    if (answerSeenBeforeOptions) {
      if (/https?:\/\//i.test(line) || /(?:PT 365|Monthly Current Affairs|News today|Vision IAS|Sandhan)/i.test(line) || /^[EMD]\s+(?:FCA|CAA|CA|FA|F|U)\b/.test(line)) {
        continue;
      }
      if (/^[a-z]/.test(line)) {
        const prev = questionLines[questionLines.length - 1] || "";
        const canContinue = /\b(?:can|use|using|source|sources|of|to|for|with|from|as|above|below|following|given|a|an)$/i.test(prev);
        const allowedStart = /^(?:do|use|using|source|sources|are|is|can|may|in|of|for|with|from)\b/i.test(line);
        if (!(canContinue && allowedStart && line.length <= 40)) {
          continue;
        }
      } else if (!isLikelyQuestionLine(line) && line.length > 60) {
        continue;
      }
    }
    questionLines.push(line);
  }

  const explanationCap = 10;
  for (; i < lines.length && explanationLines.length < explanationCap; i += 1) {
    const line = lines[i];
    if (!line) continue;
    if (/^[EMD]\s+(?:FCA|CAA|CA|FA|F|U)\b/.test(line)) break;
    if (/^https?:\/\//i.test(line)) break;
    if (/^(?:RM|EM|EN|RR)\b/.test(line)) break;
    if (/^VisionIAS Test/i.test(line)) break;
    if (/^[A-Z]{1,3}$/.test(line) && explanationLines.length >= 2) break;
    explanationLines.push(line);
  }

  return {
    statementLines: cleanQuestionLines(questionLines.filter(Boolean)),
    options: {
      a: normalizeOptionText(options.a || ""),
      b: normalizeOptionText(options.b || ""),
      c: normalizeOptionText(options.c || ""),
      d: normalizeOptionText(options.d || "")
    },
    answer,
    explanationLines: explanationLines.filter(Boolean)
  };
}

function inferMetadata(section, questionText) {
  const text = questionText.toLowerCase();

  if (section.includes("S&T")) {
    const microTopic = /satellite|isro|space|orbit|nasa|gaganyaan/.test(text)
      ? "Space"
      : /gps|navic|navigation/.test(text)
        ? "Navigation"
        : /vehicle|battery|fuel cell|powertrain|electric vehicle/.test(text)
          ? "Information and Communication Technology, Robotics, AI"
        : /missile|drone|uav|fighter|defence|defense|torpedo|submarine/.test(text)
          ? "Defence"
        : /nuclear|reactor|radioactive|fusion|fission/.test(text)
            ? "Nuclear Technology"
            : /gene|genome|vaccine|biotech|biology|rna|dna|crispr|microbe|enzyme|protein/.test(text)
              ? "Biology and Biotechnology"
                : /nano/.test(text)
                  ? "Nanotechnology"
                    : /patent|ipr|copyright|trademark|gi tag/.test(text)
                      ? "IPR, Institutions and Policies for IPR"
                  : "Information and Communication Technology, Robotics, AI";
    return { subject: "Science & Technology", sectionGroup: null, microTopic };
  }

  if (section.includes("Environment")) {
    const microTopic = /ramsar|world heritage|biosphere reserve|wildlife sanctuary|national park/.test(text)
      ? "Ramsar Sites, World Heritage Sites, UNESCO Heritage Sites, WHS, Biodiversity Heritage Sites, etc."
      : /tiger reserve|elephant reserve/.test(text)
        ? "Tiger Reserve, Elephant Reserve, other species-specific reserves, etc."
        : /tiger|elephant|lion|rhino|crocodile|vulture|dolphin|tortoise|species/.test(text)
          ? "Wildlife Conservation (Tiger, Elephant, Lion, Rhino, Crocodile, Vulture, Tortoise, Dolphin, etc.)"
          : /iucn|red list|extinct|extinction/.test(text)
            ? "Mass Extinctions and IUCN Red List"
            : /greenhouse|global warming|climate change|net zero|carbon|direct air capture/.test(text)
              ? "Climate Change and Impacts of Climate Change over Earth"
              : /ozone|ghg|ods/.test(text)
                ? "Greenhouse Gases (GHG), ODS, Related Terms, Global Warming"
                : /pollution|waste|microplastic|plastic|heavy metal|e-waste/.test(text)
                  ? "Air, Water, Noise Pollution, SLCPs, etc."
                  : /epa|eia|esz|crz/.test(text)
                    ? "EPA Act, EIA, ESZ, CRZ"
                    : "Ecology and Ecosystem";
    const sectionGroup = prelimsSectionGroup("Environment", microTopic);
    return { subject: "Environment", sectionGroup, microTopic };
  }

  if (section.includes("Economy")) {
    const microTopic = /budget/.test(text)
      ? "Budget"
      : /tax|gst|customs|excise|cess/.test(text)
        ? "Taxation"
        : /rbi|repo|reverse repo|slr|crr|liquidity|monetary/.test(text)
          ? "Monetary Policy"
          : /bank|npa|deposit|loan|credit/.test(text)
            ? "Banking, NPA"
            : /stock|bond|sebi|aif|mutual fund|financial market/.test(text)
              ? "Financial Markets"
              : /insurance|pension/.test(text)
                ? "Insurance and Pension"
                : /export|import|trade|fdi|fii/.test(text)
                  ? "Trade (Exports, Imports, FDI, FII, etc.)"
                  : /imf|world bank|wto|rcep|fta/.test(text)
                    ? "International Organisations (WTO, IMF, World Bank, RCEP, FTAs, etc.)"
                    : /inflation|gdp|unemployment/.test(text)
                      ? "GDP, Inflation, Unemployment"
                      : /agriculture|msp|apmc/.test(text)
                        ? "Agriculture (Schemes, APMC, MSP, Exports, etc.)"
                        : /energy|power/.test(text)
                          ? "Energy"
                          : /road|rail|port|airport|pipeline|waterway|transport/.test(text)
                            ? "Transport"
                            : "Fiscal Policy";
    const sectionGroup = prelimsSectionGroup("Economy", microTopic);
    return { subject: "Economy", sectionGroup, microTopic };
  }

  if (section.includes("Polity")) {
    const microTopic = /anti-defection|political party|election/.test(text)
      ? "Elections, Political Parties, Anti-Defection Law"
      : /president|vice-president|governor|pardon/.test(text)
        ? "President, Vice President, Governor"
        : /prime minister|chief minister|council of ministers|cabinet/.test(text)
          ? "Prime Minister, Chief Minister, Council of Ministers, Cabinet Executive"
          : /ordinance|bill|parliament|speaker|rajya sabha|lok sabha|committee/.test(text)
            ? "Parliament Procedures, Proceedings, Officers, Bills, Committees, Houses, etc."
            : /supreme court|high court|judiciary|judge/.test(text)
              ? "Judiciary"
              : /fundamental right|article 14|article 19|article 21/.test(text)
                ? "Fundamental Rights"
                : /dpsp|directive principle/.test(text)
                  ? "Directive Principles of State Policy DPSP"
                  : /constitutional body|cag|ec|upsc|finance commission/.test(text)
                    ? "Constitutional Bodies"
                    : /tribal|scheduled area/.test(text)
                      ? "Scheduled and Tribal Areas"
                      : /municipal|panchayat|cooperative/.test(text)
                        ? "Local Government Panchayats, Municipalities, Cooperative Societies"
                        : /federal|centre-state|union|state/.test(text)
                          ? "Centre-State Relations"
                          : "Governance and Policies";
    return { subject: "Polity", sectionGroup: null, microTopic };
  }

  if (section.includes("Ancient History")) {
    const microTopic = /indus|harappa/.test(text)
      ? "Indus Valley Civilization"
      : /vedic/.test(text)
        ? "Vedic Age"
        : /buddh|jain/.test(text)
          ? "Buddhism, Jainism & Other Philosophies"
          : /maurya|ashoka/.test(text)
            ? "Mauryan Empire"
            : /gupta/.test(text)
              ? "Gupta Period"
              : /sangam/.test(text)
                ? "Sangam Age"
                : /mahajanapada|magadha/.test(text)
                  ? "Mahajanapadas"
                  : "Literature of Ancient India";
    return { subject: "History", sectionGroup: "Ancient", microTopic };
  }

  if (section.includes("Medieval History")) {
    const microTopic = /chola|southeast asia/.test(text)
      ? "Chola and other South Indian Kingdoms and Contact with Southeast Asia"
      : /delhi sultanate|slave dynasty|khilji|tughlaq/.test(text)
        ? "Delhi Sultanate & Early Muslim Invasions"
        : /mughal|sur empire/.test(text)
          ? "Mughals & Sur Empire"
          : /vijayanagara|bahmani/.test(text)
            ? "Vijayanagara Empire & Bahmani Kingdom"
            : /maratha/.test(text)
              ? "Maratha Empire"
              : "Major Dynasties of Early Medieval India";
    return { subject: "History", sectionGroup: "Medieval", microTopic };
  }

  if (section.includes("Modern History")) {
    const microTopic = /1857|revolt/.test(text)
      ? "1857 Revolt - Resistance & Revolt"
      : /peasant|worker|labour/.test(text)
        ? "Peasant & Working-Class Movements"
        : /reform|brahmo|arya samaj|aligarh/.test(text)
          ? "Socio-Religious Reform Movements"
          : /moderate|extremist|congress/.test(text)
            ? "Early National Movement - Moderates, Extremists"
            : /bhagat singh|revolutionary|hsra/.test(text)
              ? "Revolutionary Movements - Phase 1 & Phase 2"
              : /gandhi|non-cooperation|civil disobedience|quit india|simon/.test(text)
                ? "Gandhian Phase (Post-1917 till Partition, including NCM, CDM, QIM, Simon Commission, etc.)"
                : /partition|independence/.test(text)
                  ? "Partition & Independence"
                  : /act|council|constitutional/.test(text)
                    ? "Constitutional Developments"
                    : /governor general|viceroy|civil service|police|judicial/.test(text)
                      ? "Governor Generals and Their Policies, Administrative Developments, Judicial Developments, Civil Services, Police, Military"
                      : /press|education/.test(text)
                        ? "Development of Press, Education"
                        : "Advent of Europeans, British Expansion, Anglo Wars";
    return { subject: "History", sectionGroup: "Modern", microTopic };
  }

  if (section.includes("Art and Culture")) {
    const microTopic = /temple|stupa|mosque|architecture/.test(text)
      ? "Architecture"
      : /sculpture|bronze|statue/.test(text)
        ? "Sculpture"
        : /painting/.test(text)
          ? "Painting"
          : /dance|music|drama|martial/.test(text)
            ? "Performing Arts (Dance, Drama, Music, Martial Arts)"
            : /literature|book|author/.test(text)
              ? "Literature"
              : /festival/.test(text)
                ? "National and Regional Festivals"
                : /bhakti|sufi/.test(text)
                  ? "Bhakti and Sufi"
                  : "Religion & Philosophy";
    return { subject: "History", sectionGroup: "Art & Culture", microTopic };
  }

  if (section.includes("Geography")) {
    const microTopic = /earthquake|volcano/.test(text)
      ? "Earthquake and Volcanism"
      : /rock|igneous|sedimentary|metamorphic|geology/.test(text)
        ? "Geology and Rocks"
        : /landform|plateau|mountain|valley/.test(text)
          ? "Landforms"
          : /atmosphere|temperature|insolation|heat/.test(text)
            ? "Atmosphere (Composition, Structure)"
            : /pressure|wind|airmass|coriolis/.test(text)
              ? "Pressure, Winds, Airmasses (Coriolis Force, Frictional Force, etc.)"
              : /cyclone|hurricane|typhoon/.test(text)
                ? "Cyclones"
                : /el nino|la nina/.test(text)
                  ? "El Nino and La Nina"
                  : /monsoon|climate of india/.test(text)
                    ? "Climate, Monsoon"
                    : /river|drainage/.test(text)
                      ? "Drainage System, Rivers, River Interlinking"
                      : /soil/.test(text)
                        ? "Soils of India"
                        : /forest|vegetation|mangrove/.test(text)
                          ? "Natural Vegetation (Forests, Trees, Vegetation)"
                          : /ocean current/.test(text)
                            ? "Ocean Currents"
                            : /tide|wave/.test(text)
                              ? "Movement of Ocean Water (Tides, Waves, etc.)"
                              : /strait|channel|gulf|bay|sea|ocean/.test(text)
                                ? "Straits, Channels, Oceans, Seas, Gulfs, Bays"
                                : /port|trade route/.test(text)
                                  ? "Major Ports, Trade Routes"
                                  : "Physiography of India (Location, Division, Physiographic Regions)";
    const sectionGroup = prelimsSectionGroup("Geography", microTopic);
    return { subject: "Geography", sectionGroup, microTopic };
  }

  if (section.includes("International Relations")) {
    const microTopic = /un |imf|world bank|asean|brics|nato|who/.test(` ${text} `)
      ? "International Organizations (UN, IMF, World Bank, ASEAN, BRICS, etc.)"
      : /quad|paris agreement|npt|fta|agreement|treaty/.test(text)
        ? "Global Groupings and Agreements (FTA, Paris Agreement, NPT, QUAD, etc.)"
        : /ukraine|taiwan|hormuz|gaza|hotspot/.test(text)
          ? "Places in News and Geopolitical Hotspots (Ukraine, Taiwan Strait, Hormuz, etc.)"
          : /pakistan|china|nepal|sri lanka|bangladesh|myanmar|bhutan|maldives/.test(text)
            ? "India and Neighbourhood (Pakistan, China, Nepal, Sri Lanka, etc.)"
            : /usa|russia|middle east|africa|europe|japan/.test(text)
              ? "India and the World (USA, Russia, Middle East, Africa, etc.)"
              : /terror|cyber|maritime|exercise|security/.test(text)
                ? "Security and Strategic Issues (Terrorism, Cyber, Maritime, Exercises, etc.)"
                : "Current Affairs Focus (Summits, Reports, Conflicts, Visits, etc.)";
    return { subject: "International Relations", sectionGroup: null, microTopic };
  }

  return { subject: "Current Affairs", sectionGroup: null, microTopic: "Current Affairs Focus" };
}

function prelimsSectionGroup(subject, microTopic) {
  return SECTION_GROUP_BY_SUBJECT_TOPIC.get(`${subject}|${microTopic}`) ?? null;
}

function build() {
  const raw = fs.readFileSync(INPUT_PATH, "utf8");
  const lines = raw
    .split(/\r?\n/)
    .map(cleanLine)
    .filter((line, index, array) => !(line === "" && array[index - 1] === ""));

  const startIndex = lines.findIndex((line) => /^1\s+S&T\b/.test(line));
  if (startIndex < 0) throw new Error("Could not find Question 1 in extracted text.");

  const starts = [];
  let expected = 1;
  for (let i = startIndex; i < lines.length && expected <= 100; i += 1) {
    if (isQuestionStart(lines[i], expected)) {
      starts.push(i);
      expected += 1;
    }
  }
  if (starts.length !== 100) {
    throw new Error(`Expected 100 question starts, found ${starts.length}.`);
  }

  const questions = starts.map((start, index) => {
    const end = starts[index + 1] ?? lines.length;
    const block = lines.slice(start, end).filter((line) => !isPageNoise(line));
    const { number, section, consumed, leadingLine } = splitSection(block);
    const payload = inferQuestionParts([leadingLine, ...block.slice(consumed)].filter(Boolean));
    const questionText = payload.statementLines.join(" ").replace(/\s+/g, " ").trim();
    const meta = inferMetadata(section, questionText);
    const explanationBody = normalizeText(payload.explanationLines.join(" "))
      .replace(/\s+/g, " ")
      .trim();

    return {
      id: `upsc-cse-prelims-2025-gs-paper-1-q${String(number).padStart(2, "0")}`,
      questionNumber: number,
      subject: meta.subject,
      sectionGroup: meta.sectionGroup,
      microTopic: meta.microTopic,
      originalSourceTopic: section,
      isPyq: true,
      pyqMeta: {
        group: "UPSC CSE",
        exam: "Prelims",
        year: 2025
      },
      questionTypeTags: [],
      statementLines: payload.statementLines,
      questionText,
      options: payload.options,
      correctAnswer: payload.answer || "a",
      explanationMarkdown: explanationBody
        ? `**Option ${payload.answer || "a"} is the correct answer.**\n${explanationBody}`
        : `**Option ${payload.answer || "a"} is the correct answer.**`,
      source: {
        sourceText: "UPSC CSE Prelims 2025",
        subject: meta.subject,
        topic: section,
        subtopic: ""
      }
    };
  });

  const test = {
    id: "upsc-cse-prelims-2025-gs-paper-1",
    title: "UPSC CSE Prelims 2025 • GS Paper I",
    provider: "UPSC CSE PYQ",
    series: "UPSC CSE",
    level: "Prelims",
    year: 2025,
    subject: null,
    sectionGroup: null,
    paperType: "Full Length",
    defaultMinutes: 120,
    sourceMode: "qp-sol",
    questions
  };

  fs.writeFileSync(OUTPUT_JSON, `${JSON.stringify(test, null, 2)}\n`, "utf8");
  console.log(`Wrote ${questions.length} questions to ${OUTPUT_JSON}`);
}

build();
