const axios = require("axios")
const xml2js = require("xml2js")


const fetchNews = async (category) => {
  try {
    const response = await axios.get(
      `https://www.trthaber.com/xml_mobile.php?tur=xml_genel&kategori=${category}&adet=20&selectEx=yorumSay,okunmaadedi,anasayfamanset,kategorimanset`
    )
    const parser = new xml2js.Parser()
    const jsonData = await parser.parseStringPromise(response.data)

    if (jsonData && jsonData.haberler && Array.isArray(jsonData.haberler.haber)) {
      return jsonData.haberler.haber.map((item) => {
        const haberId = Array.isArray(item.haber_id) ? item.haber_id[0] : null
        const baslik = Array.isArray(item.haber_manset) ? item.haber_manset[0] : ""
        const ozet = Array.isArray(item.haber_aciklama) ? item.haber_aciklama[0] : ""
        const haberMetni = Array.isArray(item.haber_metni) ? item.haber_metni[0] : ""
        const haberTarihi = Array.isArray(item.haber_tarihi) ? new Date(item.haber_tarihi[0]).toISOString() : null
        const kategori = Array.isArray(item.haber_kategorisi) ? item.haber_kategorisi[0] : ""
        const resim = Array.isArray(item.haber_resim) ? item.haber_resim[0] : ""
        const haberLink = Array.isArray(item.haber_link) ? item.haber_link[0] : ""

        // Senin yapına göre dönüştürülmüş nesne
        return {
          haber_id: haberId,
          baslik: baslik,
          ozet: ozet,
          haber_metni: haberMetni,
          haber_tarih: haberTarihi,
          durum: "taslak", // dış veri olduğu için default değer
          olusturma_tarihi: new Date().toISOString(),
          guncelleme_tarihi: new Date().toISOString(),
          kategoriler: kategori,
          resim_link: resim ? [resim] : [],
          video_link: [], // TRT'den gelmiyor
          kaynak: "trt",
          haber_link: haberLink // istersen frontend'de gösterirsin
        }
      })
    }

    return []
  } catch (error) {
    console.error(`TRT Haber verisi alınamadı: ${error.message}`)
    throw error
  }
}

module.exports = { fetchNews }

