const axios = require("axios");
const fs = require("fs");
const path = require("path");

const API_KEY = "3ZtBxBJ6bXe3bJB0t7lFw0:26r9LIVecUDgXit4axIcKi";

const cache_dir = path.join(__dirname, "../cache");
const requestFilePath = path.join(cache_dir, "requests.json");
const categories_dir = path.join(cache_dir, "categories");
const categories = ["sport", "health", "technology", "politic", "magazin", "education", "culture", "economy"];
const MAX_DAILY_REQUESTS = 33;
const CACHE_DURATION = 2 * 60 * 60 * 1000; // 2 saat

// Önbellek klasörü oluştur
if (!fs.existsSync(cache_dir)) {
  fs.mkdirSync(cache_dir, { recursive: true });
  console.log(`${cache_dir} klasörü oluşturuldu.`);
}

// Kategori klasörü oluştur
if (!fs.existsSync(categories_dir)) {
  fs.mkdirSync(categories_dir, { recursive: true });
  console.log(`${categories_dir} klasörü oluşturuldu.`);
}

// JSON dosyası yoksa oluştur ve istek sayısını 0 yap
if (!fs.existsSync(requestFilePath)) {
  fs.writeFileSync(requestFilePath, JSON.stringify({ requestCount: 0 }, null, 2));
  console.log(`İstek sayısı dosyası oluşturuldu: ${requestFilePath}`);
}

// JSON dosyasından istek sayısını oku
const getRequestCount = () => {
  try {
    const data = fs.readFileSync(requestFilePath, "utf-8");
    return JSON.parse(data).requestCount || 0;
  } catch (error) {
    console.error("İstek sayısı okunurken hata oluştu:", error);
    return 0;
  }
};

// JSON dosyasına istek sayısını yaz
const saveRequestCount = (count) => {
  try {
    fs.writeFileSync(requestFilePath, JSON.stringify({ requestCount: count }, null, 2));
    console.log(`İstek sayısı kaydedildi: ${count}`);
  } catch (error) {
    console.error("İstek sayısı kaydedilirken hata oluştu:", error);
  }
};

// Belirli bir kategori için önbellekten veriyi yükle
const loadCache = (category) => {
  const filePath = path.join(categories_dir, `${category}.json`);
  try {
    if (fs.existsSync(filePath)) {
      return JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
  } catch (error) {
    console.error(`Önbellek dosyası okunamadı (${category}):`, error);
  }
  return null;
};

// Belirli bir kategori için haberleri kaydet
const createSaveCategory = (category, newsData) => {
  const filePath = path.join(categories_dir, `${category}.json`);
  try {
    // Mevcut veriyi kontrol et
    let existingData = { timestamp: Date.now(), data: [] };
    
    if (fs.existsSync(filePath)) {
      existingData = JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
    
    // Mevcut verilerin son key değerini bul
    let lastKey = -1;
    if (existingData.data && Array.isArray(existingData.data) && existingData.data.length > 0) {
      existingData.data.forEach(item => {
        const itemKey = parseInt(item.key);
        if (!isNaN(itemKey) && itemKey > lastKey) {
          lastKey = itemKey;
        }
      });
    }
    
    // Yeni haberlere sıralı key değerleri ata
    const newDataWithKeys = newsData.map((item, index) => {
      return {
        ...item,
        key: String(lastKey + 1 + index)
      };
    });
    
    // Yeni verileri mevcut verilere ekle
    if (!Array.isArray(existingData.data)) {
      existingData.data = [];
    }
    
    existingData.data = [...existingData.data, ...newDataWithKeys];
    existingData.timestamp = Date.now();
    
    fs.writeFileSync(filePath, JSON.stringify(existingData, null, 2));
    console.log(`Haberler eklendi: ${category}, yeni haber sayısı: ${newDataWithKeys.length}`);
  } catch (error) {
    console.error(`Haberler kaydedilemedi (${category}):`, error);
  }
};

// API'den haberleri çek
const fetchNewsFromAPI = async (category) => {
  let requestCount = getRequestCount();

  if (requestCount >= MAX_DAILY_REQUESTS) {
    return { error: "İstek limiti doldu, yeni istek hakkın yok." };
  }

  console.log(`API'den veri çekiliyor: ${category}`);
  try {
    const response = await axios.get(`https://api.collectapi.com/news/getNews?country=tr&tag=${category}`,
      {
        headers: {
          "content-type": "application/json",
          authorization: `apikey ${API_KEY}`,
        },
      }
    );

    console.log(`API yanıtı alındı: Status ${response.status}`);

    if (!response.data || !Array.isArray(response.data.result)) {
      console.error("API verisi yanlış formatta veya boş!");
      return { error: "API verisi alınamadı" };
    }

    // İstek sayısını artır ve kaydet
    saveRequestCount(requestCount + 1);
    console.log(`İstek sayısı güncellendi: ${requestCount + 1}`);

    return response.data.result;
  } catch (error) {
    console.error("Haberler alınamadı:", error.message);
    return { error: "API isteği başarısız oldu" };
  }
};

// Kategori bazında haberleri getir
const getNewsByCategory = async (category) => {
  if (!categories.includes(category)) {
    console.log(`Geçersiz kategori: ${category}`);
    return { error: "Geçersiz kategori" };
  }

  const now = Date.now();
  const cache = loadCache(category);

  if (cache && now - cache.timestamp < CACHE_DURATION) {
    console.log(`Önbellekten getiriliyor: ${category}`);
    return cache.data;
  }

  if (getRequestCount() >= MAX_DAILY_REQUESTS) {
    console.log(`Maksimum istek sınırına ulaşıldı. Önbellekten getiriliyor: ${category}`);
    return cache ? cache.data : { error: "Önbellekte veri yok" };
  }

  const newsData = await fetchNewsFromAPI(category);

  if (!newsData.error) {
    createSaveCategory(category, newsData);
  }

  // Güncel veriyi tekrar yükle ve döndür
  const updatedCache = loadCache(category);
  return updatedCache ? updatedCache.data : newsData;
};

// Günlük istek sayısını sıfırla ve önbelleği temizle
const clearRequestCountAndCache = () => {
  console.log("İstek sayısı sıfırlanıyor...");
  saveRequestCount(0);

  console.log("Kategori dosyaları temizleniyor...");
  categories.forEach((category) => {
    const filePath = path.join(categories_dir, `${category}.json`);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log(`Silindi: ${category}.json`);
    }
  });
};

// Her 24 saatte bir istek sayısını sıfırla
setInterval(clearRequestCountAndCache, 24 * 60 * 60 * 1000);

module.exports = {
  fetchNewsFromAPI,
  getNewsByCategory,
};
