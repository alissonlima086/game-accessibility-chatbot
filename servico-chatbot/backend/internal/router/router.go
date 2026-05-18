package router

import (
	"backend/internal/handler"
	"backend/internal/middleware"
	"backend/internal/service"
	"net/http"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func SetupRoutes(
	router *gin.Engine,
	authHandler *handler.AuthHandler,
	userHandler *handler.UserHandler,
	conversationHandler *handler.ConversationHandler,
	messageHandler *handler.MessageHandler,
	adminHandler *handler.AdminHandler,
	chatHandler *handler.ChatHandler,
	authService *service.AuthService,
) {
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Trace-Id"},
		AllowCredentials: false,
	}))

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	router.GET("/swagger", func(c *gin.Context) {
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusOK, swaggerHTML)
	})
	router.StaticFile("/swagger.json", "./docs/swagger.json")

	v1 := router.Group("/api/v1")
	{
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
		}

		protected := v1.Group("")
		protected.Use(middleware.TracingMiddleware()) // gera/herda trace_id por request
		protected.Use(middleware.AuthMiddleware(authService))
		{
			protected.GET("/auth/me", authHandler.Me)

			users := protected.Group("/users")
			{
				users.GET("", userHandler.ListUsers)
				users.GET("/:id", userHandler.GetUser)
				users.PUT("/:id", userHandler.UpdateUser)
				users.DELETE("/:id", userHandler.DeleteUser)
				users.POST("", middleware.AdminOnly(), userHandler.CreateUser)
				users.GET("/:id/conversations", conversationHandler.GetUserConversations)
			}

			conversations := protected.Group("/conversations")
			{
				conversations.POST("", conversationHandler.CreateConversation)
				conversations.GET("/:id", conversationHandler.GetConversation)
				conversations.PUT("/:id", conversationHandler.UpdateConversation)
				conversations.DELETE("/:id", conversationHandler.DeleteConversation)
				conversations.POST("/:id/close", conversationHandler.CloseConversation)
				conversations.POST("/:id/archive", conversationHandler.ArchiveConversation)
				conversations.GET("/:id/messages", messageHandler.GetConversationMessages)
				conversations.POST("/:id/chat", messageHandler.SendUserMessage)
			}

			messages := protected.Group("/messages")
			{
				messages.POST("", messageHandler.CreateMessage)
				messages.GET("/:id", messageHandler.GetMessage)
				messages.DELETE("/:id", messageHandler.DeleteMessage)
			}

			chat := protected.Group("/chat")
			{
				chat.POST("", chatHandler.StartChat)
				chat.POST("/:id", chatHandler.SendMessage)
			}

			admin := protected.Group("/admin")
			admin.Use(middleware.AdminOnly())
			{
				// ── Gerenciamento de usuários ──────────────────────────────
				adminUsers := admin.Group("/users")
				{
					adminUsers.GET("", userHandler.ListUsers)
					adminUsers.GET("/:id", userHandler.GetUser)
					adminUsers.PUT("/:id", userHandler.UpdateUser)
					adminUsers.DELETE("/:id", userHandler.DeleteUser)
					adminUsers.POST("", userHandler.CreateUser)
				}

				// ── Gerenciamento de links ─────────────────────────────────
				admin.POST("/links", adminHandler.AddLinks)
				admin.GET("/links", adminHandler.ListLinks)
				admin.GET("/links/status", adminHandler.GetLinksStatus)
				admin.GET("/links/status/by-domain", adminHandler.GetLinksStatusByDomain)
				admin.DELETE("/links/*url", adminHandler.DeleteLink)

				// ── Crawler actions ────────────────────────────────────────
				admin.POST("/extract-links", adminHandler.ExtractLinks)
				admin.POST("/crawl", adminHandler.TriggerCrawl)
				admin.POST("/crawl/single", adminHandler.CrawlSinglePage)

				// ── Páginas crawleadas ─────────────────────────────────────
				admin.GET("/pages", adminHandler.ListPages)
				admin.GET("/pages/domain/:domain", adminHandler.ListPagesByDomain)
				admin.GET("/page", adminHandler.GetPage)

				// ── Domínios ───────────────────────────────────────────────
				admin.GET("/domains/:domain/stats", adminHandler.GetDomainStats)
				admin.DELETE("/domains/:domain", adminHandler.DeleteDomain)
			}
		}
	}
}

const swaggerHTML = `<!DOCTYPE html>
<html>
  <head>
    <title>Chatbot API - Swagger UI</title>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" >
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"> </script>
    <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: "/swagger.json",
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
        layout: "BaseLayout",
        deepLinking: true,
        showExtensions: true,
        showCommonExtensions: true
      })
    }
    </script>
  </body>
</html>`
