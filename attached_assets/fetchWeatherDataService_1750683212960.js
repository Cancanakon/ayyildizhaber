const axios = require("axios");

const cities = [
    { name: "Adana", latitude: 36.98615, longitude: 35.32531 },
    { name: "Ankara", latitude: 39.91987, longitude: 32.85427 },
    { name: "Istanbul", latitude: 41.01384, longitude: 28.94966 },
    { name: "Konya", latitude: 37.87135, longitude: 32.48464 },
    { name: "Izmir", latitude: 38.41273, longitude: 27.13838 },
    { name: "Antalya", latitude: 36.90812, longitude: 30.69556 },
    { name: "Bursa", latitude: 40.19559, longitude: 29.06013 },
    { name: "Trabzon", latitude: 41.005, longitude: 39.72694 },
    { name: "Hatay", latitude: 38.40227, longitude: 27.10486 },
];

/** 
 * Tüm şehirler için hava durumu verisini getirir.
 */
const getAllWeather = async () => {
    return await Promise.all(
        cities.map(async (city) => {
            const url = `https://api.open-meteo.com/v1/forecast?latitude=${city.latitude}&longitude=${city.longitude}&current_weather=true`;
            const response = await axios.get(url);
            return {
                name: city.name,
                temperature: response.data.current_weather.temperature,
                weatherCode: response.data.current_weather.weathercode,
            };
        })
    );
};

/** 
 * Belirtilen şehir için hava durumu verisini getirir.
 */
const getWeatherByCity = async (cityName) => {
    // Şehir koordinatlarını bul
    const geoResponse = await axios.get(
        `https://geocoding-api.open-meteo.com/v1/search?name=${cityName}&count=1&language=tr`
    );

    // Eğer şehir bulunamazsa hata döndür
    if (!geoResponse.data.results || geoResponse.data.results.length === 0) {
        throw new Error("Şehir bulunamadı.");
    }

    const { latitude, longitude, name } = geoResponse.data.results[0];

    // Şehir için hava durumu verisini al
    const weatherResponse = await axios.get(
        `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
    );

    return {
        name: name,
        temperature: weatherResponse.data.current_weather.temperature,
        weatherCode: weatherResponse.data.current_weather.weathercode,
    };
};

module.exports = {
    getAllWeather,
    getWeatherByCity,
};
