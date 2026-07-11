using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace EphemeraNode.Adapters.DotNet
{
    public class EphemeraNodeExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<EphemeraNodeExceptionMiddleware> _logger;
        private readonly string _collectorEndpoint;
        private readonly string _serviceName;
        private static readonly HttpClient _httpClient = new HttpClient();

        public EphemeraNodeExceptionMiddleware(
            RequestDelegate next,
            ILogger<EphemeraNodeExceptionMiddleware> logger)
        {
            _next = next;
            _logger = logger;
            _collectorEndpoint = Environment.GetEnvironmentVariable("EPHEMERA_COLLECTOR_URL") ?? "http://localhost:9090/ingest";
            _serviceName = Environment.GetEnvironmentVariable("SERVICE_NAME") ?? "aspnet-core-service";
        }

        public async Task Invoke(HttpContext context)
        {
            try
            {
                await _next(context);

                if (context.Response.StatusCode >= 400)
                {
                    await CaptureFailure(context, null);
                }
            }
            catch (Exception ex)
            {
                await CaptureFailure(context, ex);
                throw;
            }
        }

        private async Task CaptureFailure(HttpContext context, Exception exception)
        {
            try
            {
                var payload = new
                {
                    Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    Service = _serviceName,
                    Path = context.Request.Path.ToString(),
                    Method = context.Request.Method,
                    StatusCode = context.Response.StatusCode,
                    ErrorType = exception?.GetType().Name ?? "HTTP_ERROR",
                    ErrorMessage = exception?.Message ?? $"Request failed with status {context.Response.StatusCode}",
                    StackTrace = exception?.StackTrace ?? string.Empty,
                    Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production",
                    TraceId = context.TraceIdentifier
                };

                var json = JsonSerializer.Serialize(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                // Fire and forget to minimize latency on the main request thread
                _ = _httpClient.PostAsync(_collectorEndpoint, content).ContinueWith(t =>
                {
                    if (t.IsFaulted)
                    {
                        _logger.LogWarning("Failed to send intercept data to EphemeraNode collector: {0}", t.Exception?.Message);
                    }
                });
            }
            catch (Exception internalEx)
            {
                _logger.LogError(internalEx, "Internal error in EphemeraNode adapter");
            }
        }
    }

    public static class EphemeraNodeMiddlewareExtensions
    {
        /// <summary>
        /// Registers the EphemeraNode Mesh Viz interceptor to capture transient microservice failures.
        /// </summary>
        public static Microsoft.AspNetCore.Builder.IApplicationBuilder UseEphemeraNodeHook(
            this Microsoft.AspNetCore.Builder.IApplicationBuilder builder)
        {
            return builder.UseMiddleware<EphemeraNodeExceptionMiddleware>();
        }
    }
}