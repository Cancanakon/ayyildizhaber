const axios = require("axios");
const fs = require("fs");
const path = require("path");

const cities = [
  { name: "Adana", latitude: 36.98615, longitude: 35.32531 },
  { name: "Ankara", latitude: 39.91987, longitude: 32.85427 },
  { name: "Istanbul", latitude: 41.01384, longitude: 28.94966 },
  { name: "Konya", latitude: 37.87135, longitude: 32.48464 },
  { name: "Izmir", latitude: 38.41273, longitude: 27.13838 },
  { name: "Hatay", latitude: 38.40227, longitude: 27.10486 },
];

const today = new Date();
const year = today.getFullYear();
const month = String(today.getMonth() + 1).padStart(2, "0");
const day = String(today.getDate()).padStart(2, "0");
const formattedDate = `${year}-${month}-${day}`;

const cache_dir = path.join(__dirname, "../cache");
if (!fs.existsSync(cache_dir)) fs.mkdirSync(cache_dir, { recursive: true });

const CACHE_FILE = path.join(cache_dir, "prayerTimes.json");

// 30 gün kontrolü
const isCacheValid = (cachePath) => {
  if (!fs.existsSync(cachePath)) return false;

  const stats = fs.statSync(cachePath);
  const now = new Date();
  const modifiedTime = new Date(stats.mtime);
  const diffDays = (now - modifiedTime) / (1000 * 60 * 60 * 24);

  return diffDays < 30;
};

// Ana fonksiyon
const getAllPrayerTimes = async () => {
  try {
    if (isCacheValid(CACHE_FILE)) {
      const cachedData = fs.readFileSync(CACHE_FILE, "utf8");
      console.log("✅ Cache kullanıldı.");
      return JSON.parse(cachedData);
    }

    const prayerTimesData = await Promise.all(
      cities.map(async (city) => {
        const url = `https://vakit.vercel.app/api/timesForGPS?lat=${city.latitude}&lng=${city.longitude}&date=${formattedDate}&days=30&timezoneOffset=180&calculationMethod=Turkey&lang=tr`;
        const response = await axios.get(url);
        return { city: city.name, data: response.data };
      })
    );

    fs.writeFileSync(CACHE_FILE, JSON.stringify(prayerTimesData, null, 2), "utf8");
    console.log("🔄 Cache yenilendi ve dosya güncellendi.");

    return prayerTimesData;
  } catch (error) {
    console.error("Ezan vakti verileri alınırken hata oluştu:", error);
    throw error;
  }
};

// Belirli bir şehir için namaz vakitlerini al
const getPrayerTimeByCity = async (cityName) => {
  try {
    const geoResponse = await axios.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&language=tr`
    );

    if (!geoResponse.data.results || !geoResponse.data.results[0]) {
      throw new Error("Şehir bulunamadı.");
    }

    const { latitude, longitude } = geoResponse.data.results[0];
    const prayerTimeCityData = await axios.get(
      `https://vakit.vercel.app/api/timesForGPS?lat=${latitude}&lng=${longitude}&date=${formattedDate}&days=1&timezoneOffset=180&calculationMethod=Turkey&lang=tr`
    );

    return prayerTimeCityData.data;
  } catch (error) {
    console.error("Ezan vakti verileri alınırken hata oluştu:", error);
    throw error;
  }
};

// Türkiye'deki bölgeleri listele
const getTurkeyRegions = async () => {
  try {
    const response = await axios.get('https://vakit.vercel.app/api/regions?country=Turkey');
    return response.data;
  } catch (error) {
    console.error("Verileri alınırken hata oluştu:", error);
    throw error;
  }
};

// Dışa aktarım
module.exports = {
  getAllPrayerTimes,
  getPrayerTimeByCity,
  getTurkeyRegions,
};
