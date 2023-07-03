using Microsoft.AspNetCore.Mvc;
using StresslessApp.PostGenerator.Models;

namespace StresslessApp.PostGenerator.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class PostGenerationController : ControllerBase
    {
        private readonly ILogger<PostGenerationController> _logger;

        public PostGenerationController(ILogger<PostGenerationController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public Post Get()
        {
            _logger.LogInformation("Generating post...");
            var random = new Random();
            return new Post
            {
                Compliment = Compliments[random.Next(0, Compliments.Length - 1)],
                ImageLink = CuteImageLinks[random.Next(0, CuteImageLinks.Length - 1)]
            };
        }

        private static string[] CuteImageLinks =
        {
            @"https://wallpaperaccess.com/full/1127251.jpg"
        };

        private static string[] Compliments =
        {
            "You are the BEST!"
        };
    }
}