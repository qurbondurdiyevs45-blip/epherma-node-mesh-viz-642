package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net"
	"sync"
	"time"

	_ "github.com/lib/pq"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	pb "github.com/ephemanode/meshviz/proto"
)

const (
	maxWorkers     = 100
	batchSizeLimit = 500
	flushInterval  = 2 * time.Second
)

type CollectorServer struct {
	pb.UnimplementedTelemetryServer
	db         *sql.DB
	queue      chan *pb.TracePoint
	wg         sync.WaitGroup
	shutdownCh chan struct{}
}

func NewCollectorServer(dbDSN string) (*CollectorServer, error) {
	db, err := sql.Open("postgres", dbDSN)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(25)

	s := &CollectorServer{
		db:         db,
		queue:      make(chan *pb.TracePoint, 50000),
		shutdownCh: make(chan struct{}),
	}

	for i := 0; i < maxWorkers; i++ {
		s.wg.Add(1)
		go s.worker()
	}

	return s, nil
}

func (s *CollectorServer) ReportTrace(ctx context.Context, req *pb.TracePoint) (*pb.TraceResponse, error) {
	select {
	case s.queue <- req:
		return &pb.TraceResponse{Success: true}, nil
	default:
		return nil, status.Error(codes.ResourceExhausted, "ingestion buffer full")
	}
}

func (s *CollectorServer) worker() {
	defer s.wg.Done()
	batch := make([]*pb.TracePoint, 0, batchSizeLimit)
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()

	for {
		select {
		case point := <-s.queue:
			batch = append(batch, point)
			if len(batch) >= batchSizeLimit {
				s.flush(batch)
				batch = batch[:0]
			}
		case <-ticker.C:
			if len(batch) > 0 {
				s.flush(batch)
				batch = batch[:0]
			}
		case <-s.shutdownCh:
			if len(batch) > 0 {
				s.flush(batch)
			}
			return
		}
	}
}

func (s *CollectorServer) flush(batch []*pb.TracePoint) {
	txn, err := s.db.Begin()
	if err != nil {
		log.Printf("failed to start transaction: %v", err)
		return
	}

	stmt, err := txn.Prepare(`
		INSERT INTO trace_telemetry 
		(service_id, node_id, status_code, latency_ms, timestamp, stack_type) 
		VALUES ($1, $2, $3, $4, $5, $6)
	`)
	if err != nil {
		log.Printf("failed to prepare statement: %v", err)
		txn.Rollback()
		return
	}
	defer stmt.Close()

	for _, p := range batch {
		ts := time.Unix(p.TimestampSeconds, 0)
		_, err := stmt.Exec(p.ServiceId, p.NodeId, p.StatusCode, p.LatencyMs, ts, p.StackType)
		if err != nil {
			log.Printf("failed to execute insert: %v", err)
		}
	}

	if err := txn.Commit(); err != nil {
		log.Printf("failed to commit transaction: %v", err)
	}
}

func (s *CollectorServer) Stop() {
	close(s.shutdownCh)
	s.wg.Wait()
	s.db.Close()
}

func main() {
	dsn := "host=localhost port=5432 user=viz_user password=viz_pass dbname=ephemanode sslmode=disable"
	collector, err := NewCollectorServer(dsn)
	if err != nil {
		log.Fatalf("failed to initialize collector: %v", err)
	}

	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer(
		grpc.MaxRecvMsgSize(1024 * 1024 * 4),
		grpc.MaxConcurrentStreams(1000),
	)
	pb.RegisterTelemetryServer(grpcServer, collector)

	log.Printf("EphermaNode Collector listening on %v", lis.Addr())
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}