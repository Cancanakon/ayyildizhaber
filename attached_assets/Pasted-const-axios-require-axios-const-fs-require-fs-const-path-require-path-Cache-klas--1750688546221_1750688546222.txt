const axios = require("axios")
const fs = require("fs")
const path = require("path")

// Cache klasörü yolu
const CACHE_DIR = path.join(__dirname, "../cache")
const CACHE_DURATION = 3 * 60 * 60 * 1000 // 3 saat (milisaniye)

// Cache klasörünü oluştur
const ensureCacheDir = () => {
  if (!fs.existsSync(CACHE_DIR)) {
    fs.mkdirSync(CACHE_DIR, { recursive: true })
    console.log("Cache klasörü oluşturuldu:", CACHE_DIR)
  }
}

// Cache dosyasının geçerli olup olmadığını kontrol et
const isCacheValid = (filePath) => {
  try {
    if (!fs.existsSync(filePath)) {
      return false
    }

    const stats = fs.statSync(filePath)
    const now = Date.now()
    const fileAge = now - stats.mtime.getTime()

    return fileAge < CACHE_DURATION
  } catch (error) {
    console.error("Cache kontrol hatası:", error)
    return false
  }
}

// Cache dosyasından veri oku
const readFromCache = (fileName) => {
  try {
    const filePath = path.join(CACHE_DIR, fileName)
    if (isCacheValid(filePath)) {
      const data = fs.readFileSync(filePath, "utf8")
      console.log(`Cache'den veri okundu: ${fileName}`)
      return JSON.parse(data)
    }
    return null
  } catch (error) {
    console.error("Cache okuma hatası:", error)
    return null
  }
}

// Cache dosyasına veri yaz
const writeToCache = (fileName, data) => {
  try {
    ensureCacheDir()
    const filePath = path.join(CACHE_DIR, fileName)
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2))
    console.log(`Cache'e veri yazıldı: ${fileName}`)
  } catch (error) {
    console.error("Cache yazma hatası:", error)
  }
}

// Eski cache dosyalarını otomatik temizle
const clearOldCache = () => {
  try {
    if (!fs.existsSync(CACHE_DIR)) return

    const files = fs.readdirSync(CACHE_DIR)
    const now = Date.now()

    files.forEach((file) => {
      const filePath = path.join(CACHE_DIR, file)
      const stats = fs.statSync(filePath)
      const fileAge = now - stats.mtime.getTime()

      if (fileAge > CACHE_DURATION) {
        fs.unlinkSync(filePath)
        console.log(`Eski cache dosyası silindi: ${file}`)
      }
    })
  } catch (error) {
    console.error("Cache temizleme hatası:", error)
  }
}

// Döviz kurları çek
const fetchCurrencyMoneyData = async () => {
  const cacheFileName = "currency_money.json"

  // Önce cache'den kontrol et
  const cachedData = readFromCache(cacheFileName)
  if (cachedData) {
    return cachedData
  }

  try {
    console.log("API'den döviz verileri çekiliyor...")

    const [fetchEuro, fetchUsd, fetchGBP] = await Promise.all([
      axios.get("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=TRY"),
      axios.get("https://api.frankfurter.dev/v1/latest?base=USD&symbols=TRY"),
      axios.get("https://api.frankfurter.dev/v1/latest?base=GBP&symbols=TRY"),
    ])

    const dovizKurlari = {
      USD_Buying: fetchUsd.data.rates.TRY.toFixed(2),
      USD_Selling: (fetchUsd.data.rates.TRY * 1.02).toFixed(2),
      USD_Change: "0.00",
      EUR_Buying: fetchEuro.data.rates.TRY.toFixed(2),
      EUR_Selling: (fetchEuro.data.rates.TRY * 1.02).toFixed(2),
      EUR_Change: "0.00",
      GBP_Buying: fetchGBP.data.rates.TRY.toFixed(2),
      GBP_Selling: (fetchGBP.data.rates.TRY * 1.02).toFixed(2),
      GBP_Change: "0.00",
      guncellemeTarihi: new Date().toISOString(),
    }

    // Cache'e kaydet
    writeToCache(cacheFileName, dovizKurlari)

    return dovizKurlari
  } catch (err) {
    console.error("Döviz kurları alınırken bir hata oluştu:", err)

    // Hata durumunda eski cache'i dön (varsa)
    const oldCache = readFromCache(cacheFileName)
    if (oldCache) {
      console.log("API hatası nedeniyle eski cache verisi döndürülüyor")
      return oldCache
    }

    return {
      USD_Buying: "N/A",
      USD_Selling: "N/A",
      USD_Change: "0.00",
      EUR_Buying: "N/A",
      EUR_Selling: "N/A",
      EUR_Change: "0.00",
      GBP_Buying: "N/A",
      GBP_Selling: "N/A",
      GBP_Change: "0.00",
      error: "Veri alınamadı",
    }
  }
}

// Altın verilerini çek
const fetchCurrencyGoldData = async () => {
  const cacheFileName = "currency_gold.json"

  // Önce cache'den kontrol et
  const cachedData = readFromCache(cacheFileName)
  if (cachedData) {
    return cachedData
  }

  try {
    console.log("API'den altın verileri çekiliyor...")

    const goldResponse = await axios.get("https://kapalicarsi.apiluna.org/")
    const goldData = goldResponse.data

    const graAltin = goldData.find(item=>item.code==='ALTIN');
    const ceyAltin = goldData.find(item=>item.code==='CEYREK_YENI');
    const tamAltin = goldData.find(item=>item.code==='TEK_YENI');


    const altinKurlari = {
      GRA_Buying: Number.parseFloat(graAltin.alis).toFixed(2),
      GRA_Selling: Number.parseFloat(graAltin.satis).toFixed(2),
      GRA_Selling: Number.parseFloat(graAltin.kapanis),
      GRA_Change: "0.00",
      CEY_Buying: Number.parseFloat(ceyAltin.alis).toFixed(2),
      CEY_Selling: Number.parseFloat(ceyAltin.satis).toFixed(2),
      GRA_Selling: Number.parseFloat(ceyAltin.kapanis),

      CEY_Change: "0.00",
      TAM_Buying: Number.parseFloat(tamAltin.alis).toFixed(2),
      TAM_Selling: Number.parseFloat(tamAltin.satis).toFixed(2),
      GRA_Selling: Number.parseFloat(tamAltin.kapanis),

      TAM_Change: "0.00",
      guncellemeTarihi: new Date().toISOString(),
    }

    // Cache'e kaydet
    writeToCache(cacheFileName, altinKurlari)

    return altinKurlari
  } catch (err) {
    console.error("Altın verilerini çekerken hata oluştu:", err)

    // Hata durumunda eski cache'i dön (varsa)
    const oldCache = readFromCache(cacheFileName)
    if (oldCache) {
      console.log("API hatası nedeniyle eski altın cache verisi döndürülüyor")
      return oldCache
    }

    return {
      GRA_Buying: "N/A",
      GRA_Selling: "N/A",
      GRA_Change: "0.00",
      error: "Veri alınamadı",
    }
  }
}

// Bitcoin ve kripto para verilerini çek
const fetchCurrencyCryptoData = async () => {
  const cacheFileName = "currency_crypto.json"

  // Önce cache'den kontrol et
  const cachedData = readFromCache(cacheFileName)
  if (cachedData) {
    return cachedData
  }

  try {
    console.log("API'den kripto para verileri çekiliyor...")

    const cryptoResponse = await axios.get(
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,binancecoin&vs_currencies=try",
    )

    const kriptoKurlari = {
      BTC_Buying: Math.round(cryptoResponse.data.bitcoin.try).toString(),
      BTC_Selling: Math.round(cryptoResponse.data.bitcoin.try * 1.01).toString(),
      BTC_Change: "0.00",
      ETH_Buying: Math.round(cryptoResponse.data.ethereum.try).toString(),
      ETH_Selling: Math.round(cryptoResponse.data.ethereum.try * 1.01).toString(),
      ETH_Change: "0.00",
      BNB_Buying: Math.round(cryptoResponse.data.binancecoin.try).toString(),
      BNB_Selling: Math.round(cryptoResponse.data.binancecoin.try * 1.01).toString(),
      BNB_Change: "0.00",
      guncellemeTarihi: new Date().toISOString(),
    }

    // Cache'e kaydet
    writeToCache(cacheFileName, kriptoKurlari)

    return kriptoKurlari
  } catch (err) {
    console.error("Kripto para verilerini çekerken hata oluştu:", err)

    // Hata durumunda eski cache'i dön (varsa)
    const oldCache = readFromCache(cacheFileName)
    if (oldCache) {
      console.log("API hatası nedeniyle eski kripto cache verisi döndürülüyor")
      return oldCache
    }

    return {
      BTC_Buying: "N/A",
      BTC_Selling: "N/A",
      BTC_Change: "0.00",
      error: "Veri alınamadı",
    }
  }
}

// Geçmiş veriler için mock data (grafik için)
const getAllCurrencyHistory = async () => {
  try {
    // Basit mock data döndür
    const mockHistory = []
    const now = new Date()

    for (let i = 9; i >= 0; i--) {
      const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
      mockHistory.push({
        timestamp: date.toISOString(),
        money: {
          USD: { buying: (34.5 + Math.random() * 2).toFixed(2), selling: (34.7 + Math.random() * 2).toFixed(2) },
          EUR: { buying: (37.2 + Math.random() * 2).toFixed(2), selling: (37.4 + Math.random() * 2).toFixed(2) },
          GBP: { buying: (43.1 + Math.random() * 2).toFixed(2), selling: (43.3 + Math.random() * 2).toFixed(2) },
        },
        gold: {
          GRA: { buying: (2850 + Math.random() * 100).toFixed(2), selling: (2870 + Math.random() * 100).toFixed(2) },
        },
        crypto: {
          BTC: {
            buying: (1800000 + Math.random() * 100000).toFixed(0),
            selling: (1810000 + Math.random() * 100000).toFixed(0),
          },
        },
      })
    }

    return mockHistory
  } catch (error) {
    console.error("Geçmiş veriler alınırken hata:", error)
    return []
  }
}

// Her saat eski cache dosyalarını kontrol et ve temizle
setInterval(clearOldCache, 60 * 60 * 1000)

module.exports = {
  fetchCurrencyMoneyData,
  fetchCurrencyGoldData,
  fetchCurrencyCryptoData,
  getAllCurrencyHistory,
}
