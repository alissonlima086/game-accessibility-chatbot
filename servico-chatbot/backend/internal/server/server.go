package server

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"backend/internal/config"
	grpcclient "backend/internal/grpc"
	"backend/internal/handler"
	"backend/internal/repository/postgres"
	"backend/internal/router"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Server struct {
	httpServer *http.Server
	config     *config.Config
}

func New(cfg *config.Config) (*Server, error) {
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	engine := gin.Default()

	db, err := waitForDB(func() (*pgxpool.Pool, error) {
		return postgres.NewConnection(&cfg.Database)
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}
	log.Println("Database connected successfully")

	adminClient, err := grpcclient.NewAdminClient(&cfg.GRPC)
	if err != nil {
		log.Printf("Warning: Failed to connect to admin gRPC: %v", err)
	}

	searchClient, err := grpcclient.NewSearchClient(&cfg.GRPC)
	if err != nil {
		log.Printf("Warning: Failed to connect to search gRPC: %v", err)
	}

	// Repositórios
	userRepo := postgres.NewUserRepository(db)
	conversationRepo := postgres.NewConversationRepository(db)
	messageRepo := postgres.NewMessageRepository(db)

	// Serviços
	authService := service.NewAuthService(userRepo, cfg.JWT.SecretKey, cfg.JWT.ExpirationHours)
	userService := service.NewUserService(userRepo)
	conversationService := service.NewConversationService(conversationRepo, messageRepo, userRepo)
	messageService := service.NewMessageService(messageRepo, conversationRepo)

	// Handlers
	authHandler := handler.NewAuthHandler(authService)
	userHandler := handler.NewUserHandler(userService)
	conversationHandler := handler.NewConversationHandler(conversationService)
	messageHandler := handler.NewMessageHandler(messageService, searchClient)
	adminHandler := handler.NewAdminHandler(adminClient)
	chatHandler := handler.NewChatHandler(conversationService, messageService, searchClient)

	router.SetupRoutes(engine, authHandler, userHandler, conversationHandler, messageHandler, adminHandler, chatHandler, authService)

	httpServer := &http.Server{
		Addr:         ":" + cfg.Server.Port,
		Handler:      engine,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	return &Server{
		httpServer: httpServer,
		config:     cfg,
	}, nil
}

func (s *Server) Start() error {
	log.Printf("Starting server on port %s", s.config.Server.Port)
	return s.httpServer.ListenAndServe()
}

func waitForDB(connect func() (*pgxpool.Pool, error)) (*pgxpool.Pool, error) {
	var db *pgxpool.Pool
	var err error
	for i := 0; i < 10; i++ {
		db, err = connect()
		if err == nil {
			return db, nil
		}
		log.Printf("Waiting for database... (%d/10)", i+1)
		time.Sleep(2 * time.Second)
	}
	return nil, err
}