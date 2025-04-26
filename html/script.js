let activeAuction = null;
let auctions = [];
let bidCooldown = false;
let cooldownTime = 5; 
let countdownIntervals = {};

$(document).ready(function() {
    $("#auction-container").css({
        'display': 'none',
        'visibility': 'hidden'
    });
    $(".preview-mode-container").css({
        'display': 'none'
    });
});

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === "openAuctionMenu") {
        $("#auction-container").css({
            'display': 'flex',
            'visibility': 'visible'
        });
        
        if (data.loading) {
            $("#auction-list").html('<div class="loading">Loading auctions...</div>');
        }
    } else if (data.action === "updateAuctions") {
        
        auctions = data.auctions || [];
        updateAuctionsList(auctions);
        if (!data.loading) {
            $("#loading").hide();
        }
    } else if (data.action === "updateBidHistory") {
        updateBidHistory(data.history);
    } else if (data.action === "showAuctionMenu") {
        $("#auction-container").css({
            'display': 'flex',
            'visibility': 'visible'
        });
    } else if (data.action === "hideUI") {
        closeUI();
    } else if (data.action === "bidFailed") {
        showNotification(data.message, "error");
        bidCooldown = false;
        $("#bid-btn").prop("disabled", false).html("Place Bid");
    } else if (data.action === "bidSuccess") {
        showNotification(data.message, "success");
        startBidCooldown();
    } else if (data.action === "showPreviewMode") {
        $("#auction-container").addClass("preview-mode");
        $(".preview-mode-container").css({
            'display': 'block'
        });
    } else if (data.action === "hidePreviewMode") {
        $("#auction-container").removeClass("preview-mode");
        $(".preview-mode-container").css({
            'display': 'none'
        });
    } else if (data.action === "updatePreviewName") {
        $(".preview-vehicle-name").text(data.name);
    }
});

function updateAuctionsList(auctionsList) {
    
    const auctionContainer = $("#auction-list");
    auctionContainer.empty();

    if (!auctionsList || auctionsList.length === 0) {
        auctionContainer.html('<div class="no-auctions"></div>');
        return;
    }

    auctionsList.forEach(auction => {
        
        let timeDisplay = formatTimeRemaining(auction.timeRemaining);
        
        let currentBid = parseInt(auction.currentBid).toLocaleString('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
        
        const auctionItem = $(`
            <div class="auction-item" data-id="${auction.id}">
                <div class="vehicle-info">
                    <h3>${auction.vehicleName}</h3>
                    <div class="auction-details">
                        <span class="detail"><i class="fas fa-money-bill-wave"></i> ${currentBid}</span>
                        <span class="detail"><i class="fas fa-clock"></i> <span class="time-remaining">${timeDisplay}</span></span>
                        <span class="detail"><i class="fas fa-user"></i> ${auction.highestBidderName}</span>
                    </div>
                </div>
            </div>
        `);

        auctionContainer.append(auctionItem);

        if (auction.timeRemaining > 0) {
            startCountdown(auction.id, auction.timeRemaining);
        }
    });
}

function formatTimeRemaining(seconds) {
    if (seconds <= 0) return "Ended";
    
    const days = Math.floor(seconds / 86400);
    seconds -= days * 86400;
    
    const hours = Math.floor(seconds / 3600);
    seconds -= hours * 3600;
    
    const minutes = Math.floor(seconds / 60);
    seconds -= minutes * 60;
    
    if (days > 0) {
        return `${days}d ${hours}h`;
    } else if (hours > 0) {
        return `${hours}h ${minutes}m`;
    } else if (minutes > 0) {
        return `${minutes}m ${seconds}s`;
    } else {
        return `${seconds}s`;
    }
}

function startCountdown(auctionId, timeRemaining) {
    if (countdownIntervals[auctionId]) {
        clearInterval(countdownIntervals[auctionId]);
    }
    
    const countdownElement = $(`.auction-item[data-id="${auctionId}"] .time-remaining`);
    let secondsLeft = timeRemaining;
    
    countdownIntervals[auctionId] = setInterval(() => {
        secondsLeft--;
        
        if (secondsLeft <= 0) {
            clearInterval(countdownIntervals[auctionId]);
            countdownElement.text("Ended");
            
            removeAuctionFromDisplay(auctionId);
            return;
        }
        
        countdownElement.text(formatTimeRemaining(secondsLeft));
    }, 1000);
}

function selectAuction(auctionId) {
    $(".auction-item").removeClass("selected");
    $(`.auction-item[data-id="${auctionId}"]`).addClass("selected");
    
    const auction = auctions.find(a => a.id === auctionId);
    if (!auction) return;
    
    activeAuction = auction;
    
    let formattedBid = parseInt(auction.currentBid).toLocaleString('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    });
    
    $(".vehicle-name").text(auction.vehicleName || auction.vehicle);
    $(".current-bid").text(formattedBid);
    $(".time-left").text(formatTimeRemaining(auction.timeRemaining));
    
    $("#main-preview-btn").data("vehicle", auction.vehicle);
    
    $("#bid-amount").val(auction.currentBid + 1000);
    $("#bid-amount").attr("min", auction.currentBid + 1000);
    
    $(".bid-controls").show();
    $(".bid-button").prop("disabled", false);
    $(".quick-bid").prop("disabled", false);
    
    $(".bid-list").html('<div class="loading">Loading bid history...</div>');
    
    $.post('https://Ranjit-Car_Auction/getBidHistory', JSON.stringify({
        auctionId: auctionId
    }));
    
    if (auction.timeRemaining > 0) {
        const detailCountdownElement = $(".time-left");
        let secondsLeft = auction.timeRemaining;
        
        if (countdownIntervals["detail"]) {
            clearInterval(countdownIntervals["detail"]);
        }
        
        countdownIntervals["detail"] = setInterval(() => {
            secondsLeft--;
            
            if (secondsLeft <= 0) {
                clearInterval(countdownIntervals["detail"]);
                detailCountdownElement.text("Ended");
                $(".bid-button").prop("disabled", true);
                $(".quick-bid").prop("disabled", true);
            } else {
                detailCountdownElement.text(formatTimeRemaining(secondsLeft));
            }
        }, 1000);
    }
}

function updateBidHistory(history) {
    const historyContainer = $("#bid-history-list");
    historyContainer.empty();

    if (!history || history.length === 0) {
        historyContainer.html('<div class="no-history">No bids have been placed yet</div>');
        return;
    }

    history.forEach(bid => {
        const bidTime = new Date(bid.timestamp * 1000).toLocaleString();
        const bidAmount = parseInt(bid.amount).toLocaleString('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
        
        historyContainer.append(`
            <div class="bid-history-item">
                <div class="bidder">${bid.charName}</div>
                <div class="bid-amount">${bidAmount}</div>
                <div class="bid-time">${bidTime}</div>
            </div>
        `);
    });
}

function previewVehicle(vehicle) {
    $.post('https://Car/previewVehicle', JSON.stringify({
        vehicle: vehicle
    }));
}

function startBidCooldown() {
    bidCooldown = true;
    $("#bid-btn").prop("disabled", true);
    
    let countdown = cooldownTime;
    $("#bid-btn").html(`Wait (${countdown}s)`);
    
    const cooldownInterval = setInterval(() => {
        countdown--;
        $("#bid-btn").html(`Wait (${countdown}s)`);
        
        if (countdown <= 0) {
            clearInterval(cooldownInterval);
            bidCooldown = false;
            $("#bid-btn").prop("disabled", false).html("Place Bid");
        }
    }, 1000);
}

function removeAuctionFromDisplay(auctionId) {
    $(`.auction-item[data-id="${auctionId}"]`).fadeOut(500, function() {
        $(this).remove();
        
        if (activeAuction && activeAuction.id === auctionId) {
            activeAuction = null;
            
            const firstAuction = $(".auction-item").first();
            if (firstAuction.length > 0) {
                selectAuction(parseInt(firstAuction.data("id")));
            } else {
                $("#auction-detail").html('<div class="no-auctions">No active auctions available</div>');
            }
        }
        
        if ($(".auction-item").length === 0) {
            $("#auction-list").html('<div class="no-auctions">No active auctions available</div>');
        }
    });
}

function closeUI() {
    $("#auction-container").css({
        'display': 'none',
        'visibility': 'hidden'
    });
    $("#preview-controls").css({
        'display': 'none',
        'visibility': 'hidden'
    });
    
    Object.keys(countdownIntervals).forEach(key => {
        clearInterval(countdownIntervals[key]);
    });
    countdownIntervals = {};
    
    $.post('https://Car/closeUI', JSON.stringify({}));
}

function showNotification(message, type = "info") {
    const notification = $(`<div class="notification ${type}">${message}</div>`);
    $("#notifications").append(notification);
    
    setTimeout(() => {
        notification.addClass("show");
        
        setTimeout(() => {
            notification.removeClass("show");
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, 3000);
    }, 100);
}

$(document).ready(function() {
    $(".close-btn").on("click", closeUI);
    
    $(document).on("click", ".auction-item", function(e) {
        if (!$(e.target).hasClass("preview-btn")) {
            const auctionId = parseInt($(this).data("id"));
            selectAuction(auctionId);
            
            $.post('https://Car/selectAuction', JSON.stringify({
                auctionId: auctionId
            }));
        }
    });
    
    $(document).on("click", ".preview-btn", function(e) {
        e.stopPropagation();
        const vehicle = $(this).data("vehicle");
        previewVehicle(vehicle);
    });
    
    $(document).on("click", ".bid-button", function() {
        if (bidCooldown || !activeAuction) return;
        
        const bidAmount = parseInt($("#bid-amount").val());
        if (!bidAmount || bidAmount <= activeAuction.currentBid) {
            showNotification("Bid must be higher than the current bid", "error");
            return;
        }
        
        if (bidAmount < activeAuction.currentBid + 1000) {
            showNotification("Minimum bid increment is $1,000", "error");
            return;
        }
        
        $.post('https://Car/placeBid', JSON.stringify({
            auctionId: activeAuction.id,
            bidAmount: bidAmount
        }));
        
        startBidCooldown();
    });
    
    $(document).on("click", ".quick-bid", function() {
        if (bidCooldown || !activeAuction) return;
        
        const quickBidAmount = activeAuction.currentBid + 2500;
        
        $.post('https://Car/placeBid', JSON.stringify({
            auctionId: activeAuction.id,
            bidAmount: quickBidAmount
        }));
        
        startBidCooldown();
    });
    
    $(".rotate-left").on("click", function() {
        $(this).addClass("active");
        setTimeout(() => { $(this).removeClass("active"); }, 200);
        $.post('https://Car/rotatePreview', JSON.stringify({ direction: "left" }));
    });
    
    $(".rotate-right").on("click", function() {
        $(this).addClass("active");
        setTimeout(() => { $(this).removeClass("active"); }, 200);
        $.post('https://Car/rotatePreview', JSON.stringify({ direction: "right" }));
    });
    
    $(".close-preview").on("click", function() {
        $.post('https://Car/closePreview', JSON.stringify({}));
    });
    
    $(document).on("keyup", function(e) {
        if (e.key === "Escape") {
            closeUI();
        }
    });
});
