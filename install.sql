-- Vehicle Auction System Database Schema
-- Run this script to initialize the required database tables

-- Table for storing active vehicle auctions
CREATE TABLE IF NOT EXISTS vehicle_auctions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle VARCHAR(50) NOT NULL,
    startingBid INT NOT NULL,
    currentBid INT NOT NULL,
    endTime INT NOT NULL,
    createdBy VARCHAR(50) NOT NULL,
    highestBidder VARCHAR(50) NULL
);

-- Table for storing auction bid history
CREATE TABLE IF NOT EXISTS auction_bids (
    id INT AUTO_INCREMENT PRIMARY KEY,
    auctionId INT NOT NULL,
    bidder VARCHAR(50) NOT NULL,
    amount INT NOT NULL,
    timestamp INT NOT NULL,
    FOREIGN KEY (auctionId) REFERENCES vehicle_auctions(id)
);

-- Table for storing vehicle claims after auction completion
CREATE TABLE IF NOT EXISTS auction_claims (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    vehicle VARCHAR(50) NOT NULL,
    claim_expires INT NOT NULL,
    claimed BOOLEAN NOT NULL DEFAULT 0
);

-- Add indexes for optimized query performance
CREATE INDEX IF NOT EXISTS idx_vehicle_auctions_end_time ON vehicle_auctions(endTime);
CREATE INDEX IF NOT EXISTS idx_auction_bids_auction_id ON auction_bids(auctionId);
CREATE INDEX IF NOT EXISTS idx_auction_bids_bidder ON auction_bids(bidder);
CREATE INDEX IF NOT EXISTS idx_auction_claims_citizenid ON auction_claims(citizenid);
CREATE INDEX IF NOT EXISTS idx_auction_claims_claimed ON auction_claims(claimed);
