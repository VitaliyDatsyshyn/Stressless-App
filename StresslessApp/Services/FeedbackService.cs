using Dapr.Client;
using StresslessApp.Models;

namespace StresslessApp.Services
{
    public class FeedbackService
    {
        private readonly ILogger<FeedbackService> _logger;

        public FeedbackService(ILogger<FeedbackService> logger)
        {
            _logger = logger;
        }

        public async Task SendFeedbackAsync(bool isAppUseful)
        {
            _logger.LogInformation($"Is this app useful? {isAppUseful}");

            using var daprClient = new DaprClientBuilder().Build();
            await daprClient.PublishEventAsync("pubsub", "feedback-queue", new Feedback { IsPositive = isAppUseful });

            _logger.LogInformation("Feedback published.");
        }
    }
}
