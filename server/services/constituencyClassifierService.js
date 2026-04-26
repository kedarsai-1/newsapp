const DEFAULT_POLITICIAN = 'Nara Chandrababu Naidu';

const constituencyMap = {
  "Ichchapuram": ["Ichchapuram", "Srikakulam", DEFAULT_POLITICIAN],
  "Palasa": ["Palasa", "Srikakulam", DEFAULT_POLITICIAN],
  "Tekkali": ["Tekkali", "Srikakulam", DEFAULT_POLITICIAN],
  "Pathapatnam": ["Pathapatnam", "Srikakulam", DEFAULT_POLITICIAN],
  "Srikakulam": ["Srikakulam", DEFAULT_POLITICIAN],
  "Amadalavalasa": ["Amadalavalasa", "Srikakulam", DEFAULT_POLITICIAN],
  "Etcherla": ["Etcherla", "Srikakulam", "Vizianagaram", DEFAULT_POLITICIAN],
  "Narasannapeta": ["Narasannapeta", "Srikakulam", DEFAULT_POLITICIAN],
  "Rajam": ["Rajam", "Vizianagaram", DEFAULT_POLITICIAN],
  "Palakonda": ["Palakonda", "Parvathipuram Manyam", "Araku", DEFAULT_POLITICIAN],
  "Kurupam": ["Kurupam", "Parvathipuram Manyam", "Araku", DEFAULT_POLITICIAN],
  "Parvathipuram": ["Parvathipuram", "Parvathipurum", "Parvathipuram Manyam", "Araku", DEFAULT_POLITICIAN],
  "Salur": ["Salur", "Parvathipuram Manyam", "Araku", DEFAULT_POLITICIAN],
  "Bobbili": ["Bobbili", "Vizianagaram", DEFAULT_POLITICIAN],
  "Cheepurupalli": ["Cheepurupalli", "Cheepurupalle", "Vizianagaram", DEFAULT_POLITICIAN],
  "Gajapathinagaram": ["Gajapathinagaram", "Vizianagaram", DEFAULT_POLITICIAN],
  "Nellimarla": ["Nellimarla", "Vizianagaram", DEFAULT_POLITICIAN],
  "Vizianagaram": ["Vizianagaram", DEFAULT_POLITICIAN],
  "Srungavarapukota": ["Srungavarapukota", "S Kota", "Vizianagaram", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Bhimili": ["Bhimili", "Bheemili", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Visakhapatnam East": ["Visakhapatnam East", "Vizag East", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Visakhapatnam South": ["Visakhapatnam South", "Vizag South", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Visakhapatnam North": ["Visakhapatnam North", "Vizag North", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Visakhapatnam West": ["Visakhapatnam West", "Vizag West", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Gajuwaka": ["Gajuwaka", "Visakhapatnam", DEFAULT_POLITICIAN],
  "Chodavaram": ["Chodavaram", "Anakapalli", DEFAULT_POLITICIAN],
  "Madugula": ["Madugula", "Anakapalli", DEFAULT_POLITICIAN],
  "Araku Valley": ["Araku Valley", "Araku", "Alluri Sitharama Raju", DEFAULT_POLITICIAN],
  "Paderu": ["Paderu", "Alluri Sitharama Raju", "Araku", DEFAULT_POLITICIAN],
  "Anakapalle": ["Anakapalle", "Anakapalli", DEFAULT_POLITICIAN],
  "Pendurthi": ["Pendurthi", "Anakapalli", DEFAULT_POLITICIAN],
  "Elamanchili": ["Elamanchili", "Yelamanchili", "Anakapalli", DEFAULT_POLITICIAN],
  "Payakaraopet": ["Payakaraopet", "Anakapalli", DEFAULT_POLITICIAN],
  "Narsipatnam": ["Narsipatnam", "Anakapalli", "Ayyannapatrudu"],
  "Tuni": ["Tuni", "Kakinada", DEFAULT_POLITICIAN],
  "Prathipadu (Kakinada)": ["Prathipadu", "Prathipadu Kakinada", "Kakinada", DEFAULT_POLITICIAN],
  "Pithapuram": ["Pithapuram", "Kakinada", "Pawan Kalyan"],
  "Kakinada Rural": ["Kakinada Rural", "Kakinada", DEFAULT_POLITICIAN],
  "Peddapuram": ["Peddapuram", "Kakinada", DEFAULT_POLITICIAN],
  "Anaparthy": ["Anaparthy", "East Godavari", "Rajahmundry", DEFAULT_POLITICIAN],
  "Kakinada City": ["Kakinada City", "Kakinada", DEFAULT_POLITICIAN],
  "Ramachandrapuram": ["Ramachandrapuram", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "Mummidivaram": ["Mummidivaram", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "Amalapuram": ["Amalapuram", "Konaseema", DEFAULT_POLITICIAN],
  "Razole": ["Razole", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "P. Gannavaram": ["P Gannavaram", "P. Gannavaram", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "Kothapeta": ["Kothapeta", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "Mandapeta": ["Mandapeta", "Konaseema", "Amalapuram", DEFAULT_POLITICIAN],
  "Rajanagaram": ["Rajanagaram", "East Godavari", "Rajahmundry", DEFAULT_POLITICIAN],
  "Rajahmundry City": ["Rajahmundry City", "Rajamahendravaram City", "East Godavari", "Adireddy Vasu"],
  "Rajahmundry Rural": ["Rajahmundry Rural", "Rajamahendravaram Rural", "East Godavari", DEFAULT_POLITICIAN],
  "Jaggampeta": ["Jaggampeta", "Kakinada", DEFAULT_POLITICIAN],
  "Rampachodavaram": ["Rampachodavaram", "Alluri Sitharama Raju", "Araku", DEFAULT_POLITICIAN],
  "Kovvur": ["Kovvur", "East Godavari", "Rajahmundry", DEFAULT_POLITICIAN],
  "Nidadavole": ["Nidadavole", "East Godavari", "Rajahmundry", DEFAULT_POLITICIAN],
  "Achanta": ["Achanta", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Palakollu": ["Palakollu", "Palacole", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Narasapuram": ["Narasapuram", "West Godavari", DEFAULT_POLITICIAN],
  "Bhimavaram": ["Bhimavaram", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Undi": ["Undi", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Tanuku": ["Tanuku", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Tadepalligudem": ["Tadepalligudem", "West Godavari", "Narasapuram", DEFAULT_POLITICIAN],
  "Unguturu": ["Unguturu", "Eluru", DEFAULT_POLITICIAN],
  "Denduluru": ["Denduluru", "Eluru", DEFAULT_POLITICIAN],
  "Eluru": ["Eluru", DEFAULT_POLITICIAN],
  "Gopalapuram": ["Gopalapuram", "East Godavari", "Rajahmundry", DEFAULT_POLITICIAN],
  "Polavaram": ["Polavaram", "Eluru", DEFAULT_POLITICIAN],
  "Chintalapudi": ["Chintalapudi", "Eluru", DEFAULT_POLITICIAN],
  "Tiruvuru": ["Tiruvuru", "NTR", "Vijayawada", DEFAULT_POLITICIAN],
  "Nuzvid": ["Nuzvid", "Eluru", DEFAULT_POLITICIAN],
  "Gannavaram": ["Gannavaram", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Gudivada": ["Gudivada", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Kaikalur": ["Kaikalur", "Eluru", DEFAULT_POLITICIAN],
  "Pedana": ["Pedana", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Machilipatnam": ["Machilipatnam", "Krishna", DEFAULT_POLITICIAN],
  "Avanigadda": ["Avanigadda", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Pamarru": ["Pamarru", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Penamaluru": ["Penamaluru", "Krishna", "Machilipatnam", DEFAULT_POLITICIAN],
  "Vijayawada West": ["Vijayawada West", "Vijayawada", "NTR", "Velampalli Srinivas"],
  "Vijayawada Central": ["Vijayawada Central", "Vijayawada", "NTR", DEFAULT_POLITICIAN],
  "Vijayawada East": ["Vijayawada East", "Vijayawada", "NTR", DEFAULT_POLITICIAN],
  "Mylavaram": ["Mylavaram", "NTR", "Vijayawada", DEFAULT_POLITICIAN],
  "Nandigama": ["Nandigama", "NTR", "Vijayawada", DEFAULT_POLITICIAN],
  "Jaggayyapeta": ["Jaggayyapeta", "NTR", "Vijayawada", DEFAULT_POLITICIAN],
  "Pedakurapadu": ["Pedakurapadu", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Tadikonda": ["Tadikonda", "Guntur", DEFAULT_POLITICIAN],
  "Mangalagiri": ["Mangalagiri", "Nara Lokesh", "Guntur"],
  "Ponnuru": ["Ponnuru", "Guntur", DEFAULT_POLITICIAN],
  "Vemuru": ["Vemuru", "Bapatla", DEFAULT_POLITICIAN],
  "Repalle": ["Repalle", "Bapatla", DEFAULT_POLITICIAN],
  "Tenali": ["Tenali", "Guntur", "Nadendla Manohar"],
  "Bapatla": ["Bapatla", DEFAULT_POLITICIAN],
  "Prathipadu (Guntur)": ["Prathipadu", "Prathipadu Guntur", "Guntur", DEFAULT_POLITICIAN],
  "Guntur West": ["Guntur West", "Guntur", DEFAULT_POLITICIAN],
  "Guntur East": ["Guntur East", "Guntur", "Mohammad Mustafa"],
  "Chilakaluripet": ["Chilakaluripet", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Narasaraopet": ["Narasaraopet", "Palnadu", DEFAULT_POLITICIAN],
  "Sattenapalle": ["Sattenapalle", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Vinukonda": ["Vinukonda", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Gurajala": ["Gurajala", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Macherla": ["Macherla", "Palnadu", "Narasaraopet", DEFAULT_POLITICIAN],
  "Yerragondapalem": ["Yerragondapalem", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Darsi": ["Darsi", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Parchur": ["Parchur", "Bapatla", DEFAULT_POLITICIAN],
  "Addanki": ["Addanki", "Bapatla", DEFAULT_POLITICIAN],
  "Chirala": ["Chirala", "Bapatla", DEFAULT_POLITICIAN],
  "Santhanuthalapadu": ["Santhanuthalapadu", "Prakasam", "Bapatla", DEFAULT_POLITICIAN],
  "Ongole": ["Ongole", "Prakasam", DEFAULT_POLITICIAN],
  "Kandukur": ["Kandukur", "Nellore", DEFAULT_POLITICIAN],
  "Kondapi": ["Kondapi", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Markapuram": ["Markapuram", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Giddalur": ["Giddalur", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Kanigiri": ["Kanigiri", "Prakasam", "Ongole", DEFAULT_POLITICIAN],
  "Kavali": ["Kavali", "Nellore", DEFAULT_POLITICIAN],
  "Atmakur": ["Atmakur", "Nellore", DEFAULT_POLITICIAN],
  "Kovuru": ["Kovuru", "Nellore", DEFAULT_POLITICIAN],
  "Nellore City": ["Nellore City", "Nellore", "P. Anil Kumar Yadav"],
  "Nellore Rural": ["Nellore Rural", "Nellore", "Kotamreddy Sridhar Reddy"],
  "Sarvepalli": ["Sarvepalli", "Nellore", "Tirupati", DEFAULT_POLITICIAN],
  "Gudur": ["Gudur", "Tirupati", DEFAULT_POLITICIAN],
  "Sullurpeta": ["Sullurpeta", "Tirupati", DEFAULT_POLITICIAN],
  "Venkatagiri": ["Venkatagiri", "Tirupati", DEFAULT_POLITICIAN],
  "Udayagiri": ["Udayagiri", "Nellore", DEFAULT_POLITICIAN],
  "Badvel": ["Badvel", "Kadapa", DEFAULT_POLITICIAN],
  "Rajampet": ["Rajampet", "Annamayya", DEFAULT_POLITICIAN],
  "Kadapa": ["Kadapa", DEFAULT_POLITICIAN],
  "Kodur": ["Kodur", "Annamayya", "Rajampet", DEFAULT_POLITICIAN],
  "Rayachoti": ["Rayachoti", "Annamayya", "Rajampet", DEFAULT_POLITICIAN],
  "Pulivendula": ["Pulivendula", "Pulivendla", "Kadapa", "Y. S. Jagan Mohan Reddy"],
  "Kamalapuram": ["Kamalapuram", "Kadapa", DEFAULT_POLITICIAN],
  "Jammalamadugu": ["Jammalamadugu", "Kadapa", DEFAULT_POLITICIAN],
  "Proddatur": ["Proddatur", "Kadapa", DEFAULT_POLITICIAN],
  "Mydukur": ["Mydukur", "Kadapa", DEFAULT_POLITICIAN],
  "Allagadda": ["Allagadda", "Nandyal", DEFAULT_POLITICIAN],
  "Srisailam": ["Srisailam", "Nandyal", DEFAULT_POLITICIAN],
  "Nandikotkur": ["Nandikotkur", "Nandyal", DEFAULT_POLITICIAN],
  "Kurnool": ["Kurnool", DEFAULT_POLITICIAN],
  "Panyam": ["Panyam", "Nandyal", DEFAULT_POLITICIAN],
  "Nandyal": ["Nandyal", DEFAULT_POLITICIAN],
  "Banaganapalle": ["Banaganapalle", "Nandyal", DEFAULT_POLITICIAN],
  "Dhone": ["Dhone", "Nandyal", DEFAULT_POLITICIAN],
  "Pattikonda": ["Pattikonda", "Kurnool", DEFAULT_POLITICIAN],
  "Kodumur": ["Kodumur", "Kurnool", DEFAULT_POLITICIAN],
  "Yemmiganur": ["Yemmiganur", "Kurnool", DEFAULT_POLITICIAN],
  "Mantralayam": ["Mantralayam", "Kurnool", DEFAULT_POLITICIAN],
  "Adoni": ["Adoni", "Kurnool", DEFAULT_POLITICIAN],
  "Alur": ["Alur", "Kurnool", DEFAULT_POLITICIAN],
  "Rayadurg": ["Rayadurg", "Anantapur", DEFAULT_POLITICIAN],
  "Uravakonda": ["Uravakonda", "Anantapur", DEFAULT_POLITICIAN],
  "Guntakal": ["Guntakal", "Anantapur", DEFAULT_POLITICIAN],
  "Tadipatri": ["Tadipatri", "Anantapur", DEFAULT_POLITICIAN],
  "Singanamala": ["Singanamala", "Anantapur", DEFAULT_POLITICIAN],
  "Anantapur Urban": ["Anantapur Urban", "Anantapur", DEFAULT_POLITICIAN],
  "Kalyandurg": ["Kalyandurg", "Anantapur", DEFAULT_POLITICIAN],
  "Raptadu": ["Raptadu", "Anantapur", "Hindupur", DEFAULT_POLITICIAN],
  "Madakasira": ["Madakasira", "Sri Sathya Sai", "Hindupur", DEFAULT_POLITICIAN],
  "Hindupur": ["Hindupur", "Sri Sathya Sai", "Nandamuri Balakrishna"],
  "Penukonda": ["Penukonda", "Sri Sathya Sai", "Hindupur", DEFAULT_POLITICIAN],
  "Puttaparthi": ["Puttaparthi", "Sri Sathya Sai", "Hindupur", DEFAULT_POLITICIAN],
  "Dharmavaram": ["Dharmavaram", "Sri Sathya Sai", "Hindupur", DEFAULT_POLITICIAN],
  "Kadiri": ["Kadiri", "Sri Sathya Sai", "Hindupur", DEFAULT_POLITICIAN],
  "Thamballapalle": ["Thamballapalle", "Annamayya", "Rajampet", DEFAULT_POLITICIAN],
  "Pileru": ["Pileru", "Annamayya", "Rajampet", DEFAULT_POLITICIAN],
  "Madanapalle": ["Madanapalle", "Annamayya", "Rajampet", DEFAULT_POLITICIAN],
  "Punganur": ["Punganur", "Chittoor", "Rajampet", DEFAULT_POLITICIAN],
  "Chandragiri": ["Chandragiri", "Tirupati", "Chittoor", "Nani"],
  "Tirupati": ["Tirupati", DEFAULT_POLITICIAN],
  "Srikalahasti": ["Srikalahasti", "Tirupati", DEFAULT_POLITICIAN],
  "Sathyavedu": ["Sathyavedu", "Satyavedu", "Tirupati", DEFAULT_POLITICIAN],
  "Nagari": ["Nagari", "Chittoor", DEFAULT_POLITICIAN],
  "Gangadhara Nellore": ["Gangadhara Nellore", "Chittoor", DEFAULT_POLITICIAN],
  "Chittoor": ["Chittoor", DEFAULT_POLITICIAN],
  "Puthalapattu": ["Puthalapattu", "Chittoor", DEFAULT_POLITICIAN],
  "Palamaner": ["Palamaner", "Chittoor", DEFAULT_POLITICIAN],
  "Kuppam": ["Kuppam", "Chittoor", "Nara Chandrababu Naidu"],
};

function mapToConstituency(entities) {
  for (const [constituency, keywords] of Object.entries(constituencyMap)) {
    for (const keyword of keywords) {
      if (
        entities.some((e) => String(e.text || '').toLowerCase().includes(String(keyword).toLowerCase()))
      ) {
        return constituency;
      }
    }
  }
  return 'Unknown';
}

async function extractEntities(text) {
  const nerUrl = String(process.env.NER_URL || '').trim();
  if (!nerUrl) return [];
  const payload = { text: String(text || '').trim() };
  if (!payload.text) return [];
  try {
    const response = await fetch(nerUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!response.ok) return [];
    const parsed = await response.json();
    const list = Array.isArray(parsed)
      ? parsed
      : Array.isArray(parsed?.entities)
        ? parsed.entities
        : [];
    return list
      .map((e) => ({
        text: String(e?.text || '').trim(),
        label: String(e?.label || '').trim().toUpperCase(),
      }))
      .filter((e) => e.text && (e.label === 'PERSON' || e.label === 'GPE'));
  } catch {
    return [];
  }
}

async function classifyArticleConstituency(article) {
  const text = article?.contentSnippet || article?.content || article?.title || '';
  try {
    const entities = await extractEntities(text);
    const constituency = mapToConstituency(entities);
    return {
      title: article?.title || '',
      link: article?.link || article?.sourceUrl || '',
      constituency,
      entities,
    };
  } catch {
    return {
      title: article?.title || '',
      link: article?.link || article?.sourceUrl || '',
      constituency: 'Unknown',
      entities: [],
    };
  }
}

module.exports = {
  constituencyMap,
  mapToConstituency,
  extractEntities,
  classifyArticleConstituency,
};

