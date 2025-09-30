# 📊 Hệ Thống Logging và Monitoring Recommendation System

## 🎯 Tổng Quan

Hệ thống logging được thiết kế để theo dõi chi tiết toàn bộ quá trình hoạt động của recommendation system, từ dữ liệu đầu vào, quá trình xử lý, đến kết quả cuối cùng. Điều này giúp:

- ✅ **Kiểm tra hiệu suất** từng thuật toán
- ✅ **Debug và troubleshoot** khi có lỗi
- ✅ **Phân tích user behavior** và interaction patterns
- ✅ **Tối ưu hóa** recommendation accuracy
- ✅ **Monitor performance** real-time

## 🏗️ Kiến Trúc Logging System

### 1. **RecommendationLogger (Core Service)**
- **Location**: `lib/services/recommendation_logger.dart`
- **Purpose**: Ghi log và phân tích performance
- **Storage**: JSON file trong device storage
- **Features**: 
  - Session tracking
  - Performance metrics
  - Error monitoring
  - Analytics generation

### 2. **Tích Hợp Với Repository**
- **Modified**: `RecommendationRepositoryImpl`
- **Logs**: Toàn bộ quá trình execution của mỗi algorithm
- **Metrics**: Response time, success rate, output count

### 3. **User Interaction Tracking**
- **Service**: `RecommendationTrackingService`
- **Tracks**: Views, favorites, cart additions, searches
- **Real-time**: Immediate logging khi user tương tác

### 4. **Analytics Dashboard**
- **Page**: `RecommendationAnalyticsPage`
- **Features**: Visual analytics, log viewer, performance charts

## 📝 Log Types và Data Structure

### 1. **SESSION_START**
```json
{
  "sessionId": "rec_1727734800000_123",
  "type": "SESSION_START",
  "timestamp": "2024-09-30T10:00:00.000Z",
  "userId": "user123",
  "requestedTypes": ["RecommendationType.hybrid"],
  "limit": 10,
  "additionalData": {}
}
```

### 2. **USER_PROFILE**
```json
{
  "sessionId": "rec_1727734800000_123",
  "type": "USER_PROFILE", 
  "timestamp": "2024-09-30T10:00:01.000Z",
  "userProfile": {
    "userId": "user123",
    "preferredCategories": ["Dog", "Cat"],
    "preferredBreeds": ["Golden Retriever"],
    "categoryWeights": {"Dog": 0.8, "Cat": 0.6},
    "breedWeights": {"Golden Retriever": 0.9},
    "averageSpending": 1500000,
    "lastActivity": "2024-09-30T09:00:00.000Z",
    "interactionCount": 25,
    "recentCategories": ["Dog", "Cat"]
  }
}
```

### 3. **ALGORITHM_EXECUTION**
```json
{
  "sessionId": "rec_1727734800000_123",
  "type": "ALGORITHM_EXECUTION",
  "timestamp": "2024-09-30T10:00:02.000Z",
  "algorithmType": "RecommendationType.contentBased",
  "inputCount": 100,
  "outputCount": 8,
  "executionTimeMs": 245,
  "weights": {"contentBased": 1.0},
  "success": true,
  "error": null
}
```

### 4. **HYBRID_COMBINATION**
```json
{
  "sessionId": "rec_1727734800000_123",
  "type": "HYBRID_COMBINATION",
  "timestamp": "2024-09-30T10:00:03.000Z",
  "algorithmSummary": {
    "RecommendationType.contentBased": {
      "count": 8,
      "weight": 0.25,
      "avgConfidence": 0.85,
      "topPets": [
        {"petId": "pet1", "confidence": 0.92, "reason": "Phù hợp với sở thích..."}
      ]
    }
  },
  "finalResultsCount": 10,
  "combinationTimeMs": 15,
  "finalResults": [...]
}
```

### 5. **SESSION_COMPLETE**
```json
{
  "sessionId": "rec_1727734800000_123",
  "type": "SESSION_COMPLETE",
  "timestamp": "2024-09-30T10:00:04.000Z",
  "success": true,
  "totalTimeMs": 1250,
  "recommendationCount": 10,
  "performanceMetrics": {
    "userProfileTimeMs": 150,
    "processingTimeMs": 15,
    "algorithmsExecuted": 3,
    "totalCandidates": 25,
    "uniqueCandidates": 18,
    "finalResults": 10
  },
  "recommendations": [...],
  "error": null
}
```

### 6. **USER_INTERACTION**
```json
{
  "type": "USER_INTERACTION",
  "timestamp": "2024-09-30T10:05:00.000Z",
  "userId": "user123",
  "petId": "pet1",
  "interactionType": "InteractionType.view",
  "metadata": {
    "category": "Dog",
    "breed": "Golden Retriever",
    "source": "recommendation_section"
  }
}
```

## 🚀 Cách Sử Dụng Logging System

### 1. **Kiểm Tra Logs trong Code**

```dart
// Initialize logger
await RecommendationLogger.initialize();

// Get recent logs
final logs = await RecommendationLogger.getLogs(
  startDate: DateTime.now().subtract(Duration(days: 1)),
  endDate: DateTime.now(),
);

// Get analytics report
final analytics = await RecommendationLogger.generateAnalyticsReport();
```

### 2. **Xem Logs qua Analytics Page**

```dart
// Navigate to analytics page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => RecommendationAnalyticsPage(),
  ),
);
```

### 3. **Console Logs để Debug**

Khi recommendation system hoạt động, bạn sẽ thấy logs trong console:

```
I/flutter: 🚀 Recommendation session started: rec_1727734800000_123 for user: user123
I/flutter: 👤 User profile logged for session: rec_1727734800000_123
I/flutter: 📊 Data fetching logged: pets (150ms, 100 items)
I/flutter: 🧠 Algorithm executed: RecommendationType.contentBased (245ms, 8 results)
I/flutter: 🔄 Hybrid combination logged: 10 final results in 15ms
I/flutter: ✅ Recommendation session completed: rec_1727734800000_123 (1250ms, 10 recommendations)
I/flutter: 👆 User interaction logged: InteractionType.view on pet pet1
```

## 📱 Analytics Dashboard Features

### 1. **Overview Tab**
- **Session Statistics**: Total sessions, success rate, average response time
- **User Interactions**: Total interactions by type (view, favorite, cart)
- **Performance Metrics**: Fast vs slow sessions distribution

### 2. **Logs Tab** 
- **Filterable Logs**: By date range and log type
- **Expandable Details**: JSON viewer cho mỗi log entry
- **Copy Function**: Copy logs để analysis external

### 3. **Performance Tab**
- **Response Time Analysis**: Average, min, max response times
- **Algorithm Performance**: Per-algorithm execution stats
- **Error Tracking**: Failed executions and error rates

## 🔍 Key Performance Indicators (KPIs)

### 1. **System Performance**
- **Response Time**: < 2000ms for 95% of requests
- **Success Rate**: > 98% of recommendation sessions
- **Error Rate**: < 2% of algorithm executions
- **Cache Hit Rate**: > 80% for repeat requests

### 2. **Algorithm Effectiveness**
- **Content-Based**: Average 6-8 recommendations per session
- **Collaborative**: Average 4-6 recommendations per session  
- **Trending**: Average 3-5 recommendations per session
- **Hybrid**: Average 8-10 final recommendations per session

### 3. **User Engagement**
- **Interaction Rate**: Views per recommendation shown
- **Conversion Rate**: Favorites/cart additions per view
- **Click-through Rate**: Detail page views per recommendation

## 📊 Sample Analytics Report

```json
{
  "reportGeneratedAt": "2024-09-30T15:00:00.000Z",
  "reportPeriod": {
    "startDate": "2024-09-29T00:00:00.000Z",
    "endDate": "2024-09-30T23:59:59.000Z"
  },
  "sessionStatistics": {
    "totalSessions": 156,
    "successfulSessions": 152,
    "failedSessions": 4,
    "successRate": 0.974,
    "averageResponseTimeMs": 1150.5
  },
  "userInteractions": {
    "totalInteractions": 1250,
    "interactionTypes": {
      "InteractionType.view": 850,
      "InteractionType.favorite": 280,
      "InteractionType.addToCart": 120
    }
  },
  "performanceMetrics": {
    "fastSessions": 98,
    "slowSessions": 12
  }
}
```

## 🛠️ Debugging và Troubleshooting

### 1. **Common Issues và Solutions**

**Issue**: High response time (>3000ms)
```
Solution: Check algorithm performance logs
- Look for slow algorithm executions
- Check data fetching times
- Optimize database queries
```

**Issue**: Low success rate (<95%)
```
Solution: Check error logs
- Look for SESSION_COMPLETE with success=false
- Check algorithm execution errors
- Verify Firebase connectivity
```

**Issue**: Low interaction rates
```
Solution: Analyze user behavior
- Check USER_INTERACTION logs
- Compare recommendation quality metrics
- Adjust algorithm weights
```

### 2. **Log File Management**

```dart
// Clear old logs (keep last 30 days)
await RecommendationLogger.clearOldLogs(keepDays: 30);

// Get log file path for external analysis
final logPath = RecommendationLogger.logFilePath;
print('Log file location: $logPath');
```

### 3. **Export Logs for Analysis**

```dart
// Get logs and export to external analytics tools
final logs = await RecommendationLogger.getLogs();
final jsonString = jsonEncode(logs);

// Save to file or send to analytics service
await File('recommendation_logs_export.json').writeAsString(jsonString);
```

## 📈 Optimization Strategies

### 1. **Performance Optimization**
- Monitor algorithm execution times
- Optimize slow-performing algorithms
- Implement better caching strategies
- Reduce data fetching overhead

### 2. **Accuracy Optimization**
- Track recommendation click-through rates
- A/B test different algorithm weights
- Analyze user feedback patterns
- Adjust recommendation thresholds

### 3. **User Experience Optimization**
- Monitor interaction patterns
- Optimize recommendation display order
- Reduce loading times
- Improve recommendation relevance

## 🔄 Continuous Monitoring

### 1. **Daily Monitoring**
- Check overall success rate
- Monitor response time trends
- Review error patterns
- Track user engagement metrics

### 2. **Weekly Analysis**
- Generate performance reports
- Compare algorithm effectiveness
- Analyze user behavior trends
- Plan optimization strategies

### 3. **Monthly Reviews**
- Full system performance review
- User satisfaction analysis
- Algorithm accuracy assessment
- System improvement planning

## 🎯 Next Steps

1. **Access Analytics**: Navigate to RecommendationAnalyticsPage
2. **Monitor Performance**: Check daily logs and metrics
3. **Optimize Algorithms**: Based on performance data
4. **A/B Testing**: Test different algorithm configurations
5. **User Feedback**: Incorporate user satisfaction metrics

**Log file được lưu tại**: `/data/data/com.example.pet_shop/app_flutter/recommendation_logs.json`

**Hệ thống logging sẽ tự động ghi lại mọi hoạt động của recommendation system để bạn có thể monitor và optimize hiệu suất!** 📊🚀