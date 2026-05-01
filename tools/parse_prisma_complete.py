"""
PRISMA PYQ Part 1 Parser - Complete extraction with user's micro-topic hierarchy
"""
import json
import re
from datetime import datetime

# Read the extracted text
with open('C:/Users/Dr. Yogesh/Pictures/polity pyq workbook/prisma_extracted.txt', 'r', encoding='utf-8') as f:
    text = f.read()

# User's micro-topic hierarchy mapping
MICRO_TOPICS = {
    "History": {
        "Ancient": [
            "Prehistoric Period", "Stone Age, Chalcolithic Age, Iron Age", "Indus Valley Civilization",
            "Vedic Age", "Mahajanapadas", "Buddhism, Jainism & Other Philosophies", "Mauryan Empire",
            "Post-Mauryan Period", "Gupta Period", "Post Gupta Period", "Sangam Age", "Literature of Ancient India"
        ],
        "Medieval": [
            "Major Dynasties of Early Medieval India", "Chola and other South Indian Kingdoms and Contact with Southeast Asia",
            "Delhi Sultanate & Early Muslim Invasions", "Mughals & Sur Empire", "Vijayanagara Empire & Bahmani Kingdom",
            "Maratha Empire", "Medieval Literature & Books"
        ],
        "Modern": [
            "Advent of Europeans, British Expansion, Anglo Wars", "1857 Revolt - Resistance & Revolt",
            "Peasant & Working-Class Movements", "Socio-Religious Reform Movements",
            "Early National Movement - Moderates, Extremists", "Revolutionary Movements - Phase 1 & Phase 2",
            "Gandhian Phase (Post-1917 till Partition, including NCM, CDM, QIM, Simon Commission, etc.)",
            "Partition & Independence", "Constitutional Developments",
            "Governor Generals and Their Policies, Administrative Developments, Judicial Developments, Civil Services, Police, Military",
            "Development of Press, Education"
        ],
        "Art & Culture": [
            "Architecture", "Sculpture", "Religion & Philosophy", "Bhakti and Sufi", "Painting",
            "Pottery & Numismatics", "Performing Arts (Dance, Drama, Music, Martial Arts)", "Literature",
            "GI Tags, Awards & Honours", "National and Regional Festivals"
        ]
    },
    "Geography": {
        "World Geography": [
            "Mountains, Plateaus, Valleys", "Rivers, Lakes", "Deserts", "Straits, Channels, Oceans, Seas, Gulfs, Bays",
            "Major Ports, Trade Routes", "Local Winds"
        ],
        "Indian Geography": [
            "Physiography of India (Location, Division, Physiographic Regions)", "Drainage System, Rivers, River Interlinking",
            "Climate, Monsoon", "Soils of India", "Natural Vegetation (Forests, Trees, Vegetation)", "Land Resources (Land Use, Categories, etc.)"
        ]
    },
    "Environment": {
        "General": [
            "Ecology and Ecosystem", "Biodiversity Basics (Types of Biodiversity)", "National Park, Wildlife Sanctuary, Biosphere Reserve",
            "Climate Change and Impacts of Climate Change over Earth"
        ]
    }
}

def detect_micro_topic(question_text, subject, section_group):
    """Detect micro-topic based on question content using user's hierarchy"""
    text_lower = question_text.lower()
    
    # History - Ancient
    if subject == "History" and section_group == "Ancient":
        if any(x in text_lower for x in ['indus', 'harappa', 'mohenjo', 'daro']):
            return "Indus Valley Civilization"
        elif any(x in text_lower for x in ['vedic', 'rigveda', 'samaveda', 'yajur', 'atharva', 'upanishad', 'arya']):
            return "Vedic Age"
        elif any(x in text_lower for x in ['buddha', 'buddhist', 'jain', 'mahavira', 'nirvana']):
            return "Buddhism, Jainism & Other Philosophies"
        elif any(x in text_lower for x in ['maurya', 'chandragupta', 'bindusara', 'ashoka', 'kautilya', 'arthashastra']):
            return "Mauryan Empire"
        elif any(x in text_lower for x in ['gupta', 'chandra gupta', 'samudra gupta', 'kalidasa']):
            return "Gupta Period"
        elif any(x in text_lower for x in ['sangam', 'tamil', 'chola', 'pandya', 'cher']):
            return "Sangam Age"
        elif any(x in text_lower for x in ['prehistoric', 'paleolithic', 'mesolithic', 'neolithic', 'stone age']):
            return "Prehistoric Period"
        elif any(x in text_lower for x in ['mahajanapada', 'magadha', 'kosala', 'avanti']):
            return "Mahajanapadas"
        else:
            return "Literature of Ancient India"
    
    # History - Medieval
    elif subject == "History" and section_group == "Medieval":
        if any(x in text_lower for x in ['delhi sultanate', ' Slave dynasty', 'khilji', 'tughlaq', 'sayyid', 'lodi']):
            return "Delhi Sultanate & Early Muslim Invasions"
        elif any(x in text_lower for x in ['mughal', 'babur', 'akbar', 'jahangir', 'shah jahan', 'aurangzeb', 'humayun']):
            return "Mughals & Sur Empire"
        elif any(x in text_lower for x in ['vijayanagara', 'bahmani', 'krishnadevaraya']):
            return "Vijayanagara Empire & Bahmani Kingdom"
        elif any(x in text_lower for x in ['maratha', 'shivaji', 'peshwa']):
            return "Maratha Empire"
        elif any(x in text_lower for x in ['chola', 'pallava', 'chola', 'south indian']):
            return "Chola and other South Indian Kingdoms and Contact with Southeast Asia"
        else:
            return "Major Dynasties of Early Medieval India"
    
    # History - Modern
    elif subject == "History" and section_group == "Modern":
        if any(x in text_lower for x in ['1857', 'revolt', 'mutiny', 'sepoy']):
            return "1857 Revolt - Resistance & Revolt"
        elif any(x in text_lower for x in ['gandhi', 'non-cooperation', 'civil disobedience', 'quit india', 'ncm', 'cdm', 'qim']):
            return "Gandhian Phase (Post-1917 till Partition, including NCM, CDM, QIM, Simon Commission, etc.)"
        elif any(x in text_lower for x in ['congress', 'moderate', 'extremist', 'surat split']):
            return "Early National Movement - Moderates, Extremists"
        elif any(x in text_lower for x in ['revolutionary', 'bhagat singh', 'chandra shekhar', 'subhas chandra']):
            return "Revolutionary Movements - Phase 1 & Phase 2"
        elif any(x in text_lower for x in ['partition', 'independence', '1947']):
            return "Partition & Independence"
        elif any(x in text_lower for x in ['british', 'colonial', 'east india company']):
            return "Advent of Europeans, British Expansion, Anglo Wars"
        elif any(x in text_lower for x in ['reform', 'raja ram mohan', 'dayanand', 'satyashodhak']):
            return "Socio-Religious Reform Movements"
        elif any(x in text_lower for x in ['constitutional', 'act', 'regulating', 'pitts', 'charter']):
            return "Constitutional Developments"
        elif any(x in text_lower for x in ['governor general', 'mountbatten', 'wellesley', 'dalhousie']):
            return "Governor Generals and Their Policies, Administrative Developments, Judicial Developments, Civil Services, Police, Military"
        else:
            return "Early National Movement - Moderates, Extremists"
    
    # History - Art & Culture
    elif subject == "History" and section_group == "Art & Culture":
        if any(x in text_lower for x in ['temple', 'stupa', 'cave', 'ajanta', 'ellora', 'konark', 'khajuraho']):
            return "Architecture"
        elif any(x in text_lower for x in ['sculpture', 'statue', 'idol', 'terracotta', 'bronze']):
            return "Sculpture"
        elif any(x in text_lower for x in ['painting', 'mural', 'miniature', 'madhubani', 'warli']):
            return "Painting"
        elif any(x in text_lower for x in ['dance', 'bharatanatyam', 'kathak', 'kathakali', 'odissi', 'manipuri']):
            return "Performing Arts (Dance, Drama, Music, Martial Arts)"
        elif any(x in text_lower for x in ['bhakti', 'sufi', 'sufism', 'kabir', 'nanak', 'meera']):
            return "Bhakti and Sufi"
        elif any(x in text_lower for x in ['religion', 'philosophy', 'hinduism', 'buddhism', 'jainism']):
            return "Religion & Philosophy"
        else:
            return "Literature"
    
    # Geography - World Geography
    elif subject == "Geography" and section_group == "World Geography":
        if any(x in text_lower for x in ['mountain', 'plateau', 'valley', 'peak']):
            return "Mountains, Plateaus, Valleys"
        elif any(x in text_lower for x in ['river', 'lake', 'amazon', 'nile', 'mississippi']):
            return "Rivers, Lakes"
        elif any(x in text_lower for x in ['desert', 'sahara', 'gobi', 'kalahari']):
            return "Deserts"
        elif any(x in text_lower for x in ['strait', 'channel', 'ocean', 'sea', 'gulf', 'bay']):
            return "Straits, Channels, Oceans, Seas, Gulfs, Bays"
        elif any(x in text_lower for x in ['port', 'trade route']):
            return "Major Ports, Trade Routes"
        elif any(x in text_lower for x in ['wind', 'monsoon', 'trade wind']):
            return "Local Winds"
        else:
            return "Mountains, Plateaus, Valleys"
    
    # Geography - Indian Geography
    elif subject == "Geography" and section_group == "Indian Geography":
        if any(x in text_lower for x in ['himalaya', 'ghat', 'plain', 'plateau', 'thar']):
            return "Physiography of India (Location, Division, Physiographic Regions)"
        elif any(x in text_lower for x in ['river', 'ganga', 'yamuna', 'brahmaputra', 'narmada', 'tapi', 'krishna', 'kaveri', 'godavari']):
            return "Drainage System, Rivers, River Interlinking"
        elif any(x in text_lower for x in ['monsoon', 'climate', 'rainfall', 'temperature']):
            return "Climate, Monsoon"
        elif any(x in text_lower for x in ['soil', 'alluvial', 'black soil', 'red soil', 'laterite']):
            return "Soils of India"
        elif any(x in text_lower for x in ['forest', 'vegetation', 'flora']):
            return "Natural Vegetation (Forests, Trees, Vegetation)"
        else:
            return "Physiography of India (Location, Division, Physiographic Regions)"
    
    # Environment
    elif subject == "Environment":
        if any(x in text_lower for x in ['ecosystem', 'ecology', 'food chain', 'trophic']):
            return "Ecology and Ecosystem"
        elif any(x in text_lower for x in ['biodiversity', 'species', 'flora', 'fauna', 'endemic']):
            return "Biodiversity Basics (Types of Biodiversity)"
        elif any(x in text_lower for x in ['national park', 'sanctuary', 'biosphere', 'tiger reserve']):
            return "National Park, Wildlife Sanctuary, Biosphere Reserve"
        elif any(x in text_lower for x in ['climate change', 'global warming', 'greenhouse', 'carbon']):
            return "Climate Change and Impacts of Climate Change over Earth"
        else:
            return "Ecology and Ecosystem"
    
    return None

print("Parser initialized with user micro-topic hierarchy")
print(f"Total text length: {len(text)} characters")
