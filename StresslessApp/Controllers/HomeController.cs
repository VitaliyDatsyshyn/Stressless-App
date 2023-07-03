using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using StresslessApp.Models;
using StresslessApp.Services;
using System.Diagnostics;

namespace StresslessApp.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly FeedbackService _feedbackService;

        public HomeController(ILogger<HomeController> logger, FeedbackService feedbackService)
        {
            _logger = logger;
            _feedbackService = feedbackService;
        }

        public async Task<IActionResult> Index()
        {
            _logger.LogInformation("Calling Post Generator...");

            using var daprClient = new DaprClientBuilder().Build();
            var invokeMethod = daprClient.CreateInvokeMethodRequest(HttpMethod.Get, "stresslessapp-postgenerator", "PostGeneration");
            var post = await daprClient.InvokeMethodAsync<Post>(invokeMethod);

            _logger.LogInformation($"Received post compliment: '{post?.Compliment}'");

            ViewBag.Post = post;

            return View();
        }

        public async Task<IActionResult> PositiveFeedback()
        {
            await _feedbackService.SendFeedbackAsync(true);
            return View("Feedback");
        }

        public async Task<ActionResult> NegativeFeedback()
        {
            await _feedbackService.SendFeedbackAsync(false);
            return View("Feedback");
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}