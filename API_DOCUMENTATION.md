# Ayyıldız Haber Ajansı - Mobile API Documentation

## Overview
Bu dokümantasyon, Ayyıldız Haber Ajansı mobil uygulaması için geliştirilen RESTful API'nin tüm endpoint'lerini ve kullanım örneklerini içerir.

## Base URL
```
https://your-domain.com/api/v1
```

## Authentication
Tüm API istekleri `X-API-Key` header'ı ile doğrulanmalıdır:

```
X-API-Key: ayyildizhaber_mobile_2025
```

## Response Format
Tüm API yanıtları aşağıdaki JSON formatında döner:

```json
{
  "success": true,
  "data": {
    // Actual data here
  }
}
```

Hata durumunda:
```json
{
  "success": false,
  "error": "Error message"
}
```

## Endpoints

### 1. API Information
**GET** `/api/v1/info`

API hakkında genel bilgi alır.

**Response:**
```json
{
  "success": true,
  "data": {
    "name": "Ayyıldız Haber Ajansı API",
    "version": "1.0",
    "description": "Mobile API for news and content delivery",
    "endpoints": {
      "news": "/api/v1/news",
      "categories": "/api/v1/categories",
      "search": "/api/v1/search",
      "widgets": "/api/v1/widgets/{currency|weather|prayer}",
      "ads": "/api/v1/ads",
      "live_stream": "/api/v1/live-stream",
      "recommendations": "/api/v1/recommendations",
      "homepage": "/api/v1/homepage"
    }
  }
}
```

### 2. News Endpoints

#### Get All News
**GET** `/api/v1/news`

Sayfalama ve filtreleme ile tüm haberleri alır.

**Query Parameters:**
- `page` (int): Sayfa numarası (default: 1)
- `per_page` (int): Sayfa başına item sayısı (max: 100, default: 20)
- `category_id` (int): Kategori ID'sine göre filtrele
- `is_featured` (bool): Öne çıkan haberleri filtrele
- `is_breaking` (bool): Son dakika haberlerini filtrele
- `search` (string): Başlık, içerik ve özette arama

**Example Request:**
```bash
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/news?page=1&per_page=10&category_id=1"
```

**Response:**
```json
{
  "success": true,
  "data": {
    "news": [
      {
        "id": 1,
        "title": "Haber başlığı",
        "slug": "haber-basligi",
        "summary": "Haber özeti",
        "content": "Tam haber içeriği",
        "featured_image": "https://example.com/image.jpg",
        "images": ["url1", "url2"],
        "videos": ["url1", "url2"],
        "source": "trt",
        "source_url": "https://source.com",
        "author": "Yazar adı",
        "status": "published",
        "is_featured": true,
        "is_breaking": false,
        "published_at": "2025-07-06T10:30:00",
        "created_at": "2025-07-06T10:00:00",
        "updated_at": "2025-07-06T10:15:00",
        "view_count": 150,
        "category_id": 1,
        "category": {
          "id": 1,
          "name": "Gündem",
          "slug": "gundem",
          "description": "Güncel haberler",
          "color": "#dc2626",
          "is_active": true,
          "created_at": "2025-07-01T00:00:00"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 10,
      "total": 250,
      "pages": 25
    }
  }
}
```

#### Get Single News
**GET** `/api/v1/news/{news_id}`

Tek bir haberin detayını alır ve görüntüleme sayısını artırır.

**Response:**
```json
{
  "success": true,
  "data": {
    "news": {
      // News object (same as above)
    },
    "related_news": [
      // Array of related news (5 items max)
    ]
  }
}
```

#### Get News by Slug
**GET** `/api/v1/news/slug/{slug}`

Slug ile haber detayını alır.

#### Get Featured News
**GET** `/api/v1/news/featured`

Öne çıkan haberleri alır.

**Query Parameters:**
- `limit` (int): Maksimum haber sayısı (max: 50, default: 10)

#### Get Breaking News
**GET** `/api/v1/news/breaking`

Son dakika haberlerini alır.

**Query Parameters:**
- `limit` (int): Maksimum haber sayısı (max: 20, default: 5)

#### Get Popular News
**GET** `/api/v1/stats/popular`

Görüntülenme sayısına göre popüler haberleri alır.

**Query Parameters:**
- `limit` (int): Maksimum haber sayısı (max: 50, default: 10)
- `days` (int): Kaç günlük dönem (max: 30, default: 7)

### 3. Category Endpoints

#### Get All Categories
**GET** `/api/v1/categories`

Tüm aktif kategorileri alır.

**Response:**
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": 1,
        "name": "Gündem",
        "slug": "gundem",
        "description": "Güncel haberler",
        "color": "#dc2626",
        "is_active": true,
        "created_at": "2025-07-01T00:00:00"
      }
    ]
  }
}
```

#### Get Category News
**GET** `/api/v1/categories/{category_id}/news`

Belirli bir kategorideki haberleri alır.

**Query Parameters:**
- `page` (int): Sayfa numarası
- `per_page` (int): Sayfa başına item sayısı

### 4. Search
**GET** `/api/v1/search`

Haber araması yapar.

**Query Parameters:**
- `q` (string, required): Arama sorgusu (min 3 karakter)
- `page` (int): Sayfa numarası
- `per_page` (int): Sayfa başına item sayısı

**Example:**
```bash
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/search?q=ekonomi&page=1"
```

### 5. Widget Data

#### Currency Data
**GET** `/api/v1/widgets/currency`

Döviz, altın ve kripto para verilerini alır.

**Response:**
```json
{
  "success": true,
  "data": {
    "currency": {
      "USD": {"buying": 39.79, "selling": 39.95, "change": 39.87},
      "EUR": {"buying": 46.87, "selling": 47.06, "change": 46.96}
    },
    "gold": {
      "Gram Altın": {"buying": 2844.3, "selling": 2855.7, "change": 2850}
    },
    "crypto": {
      "BTC": {"buying": 4300352, "selling": 4343356.0, "change": 0.0}
    },
    "last_updated": "2025-07-06T10:20:55.911122",
    "source": "Kapali Carsi & CoinGecko"
  }
}
```

#### Weather Data
**GET** `/api/v1/widgets/weather`

Hava durumu verilerini alır.

#### Prayer Times
**GET** `/api/v1/widgets/prayer`

Namaz vakitlerini alır.

### 6. Advertisement System

#### Get Advertisements
**GET** `/api/v1/ads`

Aktif reklamları alır.

**Query Parameters:**
- `type` (string): Reklam tipi ('sidebar', 'popup')

**Response:**
```json
{
  "success": true,
  "data": {
    "ads": [
      {
        "id": 1,
        "ad_type": "sidebar",
        "position": "left",
        "slot_number": 1,
        "title": "Reklam başlığı",
        "description": "Reklam açıklaması",
        "image_path": "/static/uploads/ad1.jpg",
        "link_url": "https://example.com",
        "is_active": true,
        "click_count": 25,
        "impression_count": 1500,
        "created_at": "2025-07-01T00:00:00"
      }
    ]
  }
}
```

#### Track Ad Click
**POST** `/api/v1/ads/{ad_id}/click`

Reklam tıklamasını izler.

#### Track Ad Impression
**POST** `/api/v1/ads/{ad_id}/impression`

Reklam görüntülenmesini izler.

### 7. Live Stream

#### Get Active Live Stream
**GET** `/api/v1/live-stream`

Aktif canlı yayın bilgilerini alır.

**Response:**
```json
{
  "success": true,
  "data": {
    "stream": {
      "id": 1,
      "name": "TRT Haber Canlı",
      "youtube_url": "https://www.youtube.com/watch?v=VIDEO_ID",
      "youtube_video_id": "VIDEO_ID",
      "embed_url": "https://www.youtube.com/embed/VIDEO_ID",
      "is_active": true,
      "is_default": true,
      "description": "Canlı haber yayını",
      "created_at": "2025-07-01T00:00:00"
    }
  }
}
```

### 8. Personalization & Recommendations

#### Get Recommendations
**GET** `/api/v1/recommendations`

Kişiselleştirilmiş haber önerileri alır.

**Headers:**
- `X-Session-ID` (optional): Kullanıcı oturum ID'si
- `X-Device-ID` (optional): Cihaz ID'si

**Query Parameters:**
- `limit` (int): Maksimum öneri sayısı (max: 50, default: 10)

**Response:**
```json
{
  "success": true,
  "data": {
    "recommendations": [
      // Array of news objects
    ],
    "session_id": "mobile_device123_hash456"
  }
}
```

#### Track User Interaction
**POST** `/api/v1/track/interaction`

Kullanıcı etkileşimlerini izler (kişiselleştirme için).

**Request Body:**
```json
{
  "session_id": "mobile_device123_hash456",
  "news_id": 123,
  "interaction_type": "view",
  "duration": 45,
  "scroll_depth": 0.75
}
```

**Interaction Types:**
- `view`: Haber görüntüleme
- `click`: Haber tıklama
- `scroll`: Sayfa kaydırma
- `share`: Paylaşım

### 9. Homepage Data

#### Get Homepage Data
**GET** `/api/v1/homepage`

Anasayfa için tüm gerekli verileri tek istekte alır.

**Response:**
```json
{
  "success": true,
  "data": {
    "breaking_news": [
      // Array of breaking news (5 items max)
    ],
    "featured_news": [
      // Array of featured news (8 items max)
    ],
    "latest_news": [
      // Array of latest news (12 items max)
    ],
    "categories": [
      {
        // Category object with news_count field
        "news_count": 45
      }
    ],
    "live_stream": {
      // Live stream object or null
    }
  }
}
```

## Error Codes

| HTTP Status | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Invalid API key |
| 404 | Not Found - Resource not found |
| 500 | Internal Server Error |

## Rate Limiting
Şu anda rate limiting uygulanmamıştır, ancak gelecekte eklenebilir.

## Example Mobile App Integration

### Swift (iOS) Example:
```swift
class NewsAPIService {
    private let baseURL = "https://your-domain.com/api/v1"
    private let apiKey = "ayyildizhaber_mobile_2025"
    
    func fetchNews(page: Int = 1, completion: @escaping (Result<NewsResponse, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "\(baseURL)/news?page=\(page)")!)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
    }
}
```

### Kotlin (Android) Example:
```kotlin
class NewsAPIService {
    private val baseUrl = "https://your-domain.com/api/v1"
    private val apiKey = "ayyildizhaber_mobile_2025"
    
    fun fetchNews(page: Int = 1): Call<NewsResponse> {
        return apiService.getNews(
            apiKey = apiKey,
            page = page
        )
    }
}
```

### Flutter Example:
```dart
class NewsAPIService {
  static const String baseUrl = 'https://your-domain.com/api/v1';
  static const String apiKey = 'ayyildizhaber_mobile_2025';
  
  Future<NewsResponse> fetchNews({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/news?page=$page'),
      headers: {'X-API-Key': apiKey},
    );
    
    if (response.statusCode == 200) {
      return NewsResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load news');
    }
  }
}
```

## Best Practices

1. **Caching**: Mobil uygulamada verileri önbelleğe alın
2. **Pagination**: Büyük listelerde sayfalama kullanın
3. **Error Handling**: Her API çağrısında hata durumlarını kontrol edin
4. **Session Management**: Kişiselleştirme için session ID'si saklayın
5. **Analytics**: Kullanıcı etkileşimlerini tracking endpoint'i ile kaydedin

## Testing

API endpoint'lerini test etmek için:

```bash
# News listesi
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/news?page=1&per_page=5"

# Kategoriler
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/categories"

# Arama
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/search?q=teknoloji"

# Anasayfa verileri
curl -H "X-API-Key: ayyildizhaber_mobile_2025" \
     "https://your-domain.com/api/v1/homepage"
```