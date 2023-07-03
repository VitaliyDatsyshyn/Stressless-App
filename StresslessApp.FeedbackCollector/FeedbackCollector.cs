using Dapr.Client;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using StresslessApp.FeedbackCollector.Models;
using System.Threading.Tasks;

namespace StresslessApp.FeedbackCollector
{
    public class FeedbackCollector
    {
        [FunctionName("FeedbackCollector")]
        public async Task Run([ServiceBusTrigger("feedback-queue", Connection = "ConnectionString")]string feedbackJson, ILogger logger)
        {
            logger.LogInformation($"ServiceBus queue trigger function processed message: {feedbackJson}");

            var feedback = JsonConvert.DeserializeObject<Feedback>(JObject.Parse(feedbackJson).SelectToken("data").ToString());

            using var daprClient = new DaprClientBuilder().Build();
            var feedbackCollection = await daprClient.GetStateAsync<FeedbackCollection>("statestore", "FeedbackCollection") ?? new FeedbackCollection();

            if (feedback.IsPositive)
            {
                feedbackCollection.PositiveFeedbacksCount++;
            }
            else
            {
                feedbackCollection.NegativeFeedbacksCount++;
            }

            await daprClient.SaveStateAsync("statestore", "FeedbackCollection", feedbackCollection);

            logger.LogInformation($"Current Positive Feedbacks Count: {feedbackCollection.PositiveFeedbacksCount}");
            logger.LogInformation($"Current Negative Feedbacks Count: {feedbackCollection.NegativeFeedbacksCount}");
        }
    }
}
