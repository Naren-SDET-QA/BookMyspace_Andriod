/**
 * BookMySpace Web Bootstrap & Application Engine
 * Dispatches flutter readiness events, mounts the responsive BookMySpace web experience,
 * and seamlessly synchronizes with the web/index.html loading lifecycle.
 */
(function() {
  'use strict';

  // 1. Master Venue Catalog (Reflecting BookMySpace Repository)
  var venues = [
    {
      id: 'v_smash_arena',
      title: 'Smash Arena Badminton & Sports Complex',
      category: 'sports_turfs',
      categoryLabel: 'Box Cricket & Badminton',
      city: 'Hyderabad',
      locality: 'Gachibowli, Financial District',
      distance: '1.2 km',
      rating: 4.9,
      reviewsCount: 238,
      pricePerHour: 650,
      priceUnit: 'hr',
      badge: '⚡ Instant Confirmation',
      badgeType: 'instant',
      image: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&auto=format&fit=crop&q=80',
      amenities: ['Indoor AC Courts', 'Yonex Flooring', 'Parking (50 Cars)', 'Changing Rooms', 'Pro Shop'],
      slots: ['06:00 AM - 07:00 AM', '07:00 AM - 08:00 AM', '06:00 PM - 07:00 PM', '08:00 PM - 09:00 PM']
    },
    {
      id: 'v_royal_palace',
      title: 'Grand Royal Convention & Marriage Hall',
      category: 'function_halls',
      categoryLabel: 'Marriage & Convention Hall',
      city: 'Hyderabad',
      locality: 'Banjara Hills, Road No. 12',
      distance: '3.4 km',
      rating: 4.8,
      reviewsCount: 194,
      pricePerHour: 45000,
      priceUnit: 'day',
      badge: '👑 Royal 10-Min Hold',
      badgeType: 'royal',
      image: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&auto=format&fit=crop&q=80',
      amenities: ['Central Air-Conditioning', 'Dining Capacity 1200+', 'Valet Parking', '2 Bridal Suites', 'Audio/Visual Setup'],
      slots: ['Morning Muhurtham (06 AM - 02 PM)', 'Evening Reception (04 PM - 11 PM)', 'Full Day Royal Booking']
    },
    {
      id: 'v_urban_nest_lodge',
      title: 'Urban Nest Luxury Hotel & Executive Suites',
      category: 'lodge_rooms',
      categoryLabel: 'Hotel & Day Rooms',
      city: 'Hyderabad',
      locality: 'Hitec City, Mindspace Metro',
      distance: '0.8 km',
      rating: 4.7,
      reviewsCount: 312,
      pricePerHour: 2200,
      priceUnit: 'night',
      badge: '⭐ Verified Stay',
      badgeType: 'verified',
      image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&auto=format&fit=crop&q=80',
      amenities: ['High-speed 500Mbps WiFi', 'Complimentary Breakfast', 'Work Desk & Chair', 'Power Backup 24/7', 'Room Service'],
      slots: ['Overnight Stay (12 PM Check-in)', 'Hourly Day Stay (4-Hour Pass)', 'Weekend Executive Suite']
    },
    {
      id: 'v_apex_coding_institute',
      title: 'Apex Tech Academy & IT Bootcamp Hub',
      category: 'institutes_classes',
      categoryLabel: 'IT & Software Coaching',
      city: 'Hyderabad',
      locality: 'Madhapur, Near Image Hospital',
      distance: '2.1 km',
      rating: 4.9,
      reviewsCount: 450,
      pricePerHour: 1499,
      priceUnit: 'course',
      badge: '🎓 Free Demo Class',
      badgeType: 'demo',
      image: 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=80',
      amenities: ['Hands-on Lab Machines', 'Industry Mentors', 'Placement Cell', 'Weekend Batches', 'Live Project Training'],
      slots: ['Morning Batch (08:00 AM - 10:00 AM)', 'Evening Weekend Batch (05:00 PM - 07:00 PM)', '1-on-1 Faculty Mentorship']
    },
    {
      id: 'v_cricket_turf_legends',
      title: 'Legends Box Cricket & Football Turf Arena',
      category: 'sports_turfs',
      categoryLabel: 'Floodlit Astro Turf',
      city: 'Hyderabad',
      locality: 'Kondapur, Botanical Garden Rd',
      distance: '2.7 km',
      rating: 4.8,
      reviewsCount: 185,
      pricePerHour: 900,
      priceUnit: 'hr',
      badge: '⚡ Floodlit 24/7',
      badgeType: 'instant',
      image: 'https://images.unsplash.com/photo-1529900244469-99853974dc45?w=800&auto=format&fit=crop&q=80',
      amenities: ['FIFA Grade Astro Turf', 'High-mast LED Floodlights', 'Free Cricket Bats & Leather Balls', 'Mineral Water Dispenser'],
      slots: ['07:00 PM - 08:00 PM', '08:00 PM - 09:00 PM', '09:00 PM - 10:00 PM', '10:00 PM - 11:00 PM (Night Special)']
    },
    {
      id: 'v_heritage_banquet',
      title: 'The Heritage Community & Banquet Lawn',
      category: 'function_halls',
      categoryLabel: 'Open Lawn & Banquet',
      city: 'Hyderabad',
      locality: 'Jubilee Hills, Road No. 36',
      distance: '4.1 km',
      rating: 4.7,
      reviewsCount: 142,
      pricePerHour: 35000,
      priceUnit: 'day',
      badge: '👑 Premium Lawn',
      badgeType: 'royal',
      image: 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=800&auto=format&fit=crop&q=80',
      amenities: ['Lush Green Open Lawn', 'Covered Buffet Area', 'Dedicated DJ Stage', 'Guest Parking (100+)'],
      slots: ['Afternoon Party (11:00 AM - 04:00 PM)', 'Evening Gala (05:00 PM - 11:00 PM)']
    }
  ];

  // 2. Active User State
  var state = {
    selectedCategory: 'all',
    searchQuery: '',
    selectedCity: 'Hyderabad',
    activeBookingVenue: null,
    bookingsList: [],
    walletBalance: 1500
  };

  // 3. Inject CSS Styles for Web Interface
  function injectStyles() {
    var style = document.createElement('style');
    style.textContent = `
      #bookmyspace-app {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", sans-serif;
        background-color: #0b0f19;
        color: #f1f5f9;
        min-height: 100vh;
        width: 100%;
        display: flex;
        flex-direction: column;
        box-sizing: border-box;
      }
      #bookmyspace-app * {
        box-sizing: border-box;
      }
      .bms-navbar {
        background: #111827;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        padding: 12px 20px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        position: sticky;
        top: 0;
        z-index: 100;
        backdrop-filter: blur(12px);
      }
      .bms-brand {
        display: flex;
        align-items: center;
        gap: 10px;
        cursor: pointer;
      }
      .bms-brand-icon {
        font-size: 26px;
        background: #1e293b;
        padding: 6px;
        border-radius: 10px;
        border: 1px solid rgba(255, 255, 255, 0.1);
      }
      .bms-brand-name {
        font-size: 20px;
        font-weight: 800;
        background: linear-gradient(135deg, #38bdf8, #2563eb);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        letter-spacing: -0.5px;
      }
      .bms-brand-tagline {
        font-size: 11px;
        color: #94a3b8;
        display: block;
      }
      .bms-nav-center {
        display: flex;
        align-items: center;
        gap: 12px;
        flex: 1;
        max-width: 580px;
        margin: 0 20px;
      }
      .bms-city-select {
        background: #1e293b;
        color: #e2e8f0;
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 13px;
        cursor: pointer;
        outline: none;
      }
      .bms-search-box {
        position: relative;
        flex: 1;
        display: flex;
        align-items: center;
      }
      .bms-search-input {
        width: 100%;
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 8px;
        padding: 8px 38px 8px 14px;
        color: #fff;
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }
      .bms-search-input:focus {
        border-color: #38bdf8;
      }
      .bms-voice-btn {
        position: absolute;
        right: 8px;
        background: transparent;
        border: none;
        color: #94a3b8;
        font-size: 16px;
        cursor: pointer;
        padding: 4px;
      }
      .bms-voice-btn:hover {
        color: #38bdf8;
      }
      .bms-nav-right {
        display: flex;
        align-items: center;
        gap: 14px;
      }
      .bms-wallet-badge {
        background: rgba(16, 185, 129, 0.15);
        color: #34d399;
        border: 1px solid rgba(16, 185, 129, 0.3);
        padding: 6px 12px;
        border-radius: 20px;
        font-size: 13px;
        font-weight: 600;
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .bms-user-avatar {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        color: white;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: bold;
        font-size: 14px;
        border: 2px solid rgba(255, 255, 255, 0.2);
        cursor: pointer;
      }

      /* Hero Section */
      .bms-hero {
        padding: 24px 20px;
        background: linear-gradient(180deg, #111827 0%, #0b0f19 100%);
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      }
      .bms-hero-container {
        max-width: 1200px;
        margin: 0 auto;
      }
      .bms-hero-headline {
        font-size: 24px;
        font-weight: 700;
        margin: 0 0 6px 0;
        color: #ffffff;
      }
      .bms-hero-sub {
        font-size: 14px;
        color: #94a3b8;
        margin: 0 0 18px 0;
      }

      /* Category Pills */
      .bms-categories {
        display: flex;
        gap: 10px;
        overflow-x: auto;
        padding-bottom: 6px;
      }
      .bms-cat-pill {
        background: #1e293b;
        color: #cbd5e1;
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 30px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 600;
        cursor: pointer;
        white-space: nowrap;
        display: flex;
        align-items: center;
        gap: 8px;
        transition: all 0.2s ease;
      }
      .bms-cat-pill:hover, .bms-cat-pill.active {
        background: #2563eb;
        color: #ffffff;
        border-color: #3b82f6;
        box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
      }

      /* Main Content Grid */
      .bms-main {
        max-width: 1200px;
        margin: 0 auto;
        padding: 24px 20px;
        flex: 1;
        width: 100%;
      }
      .bms-grid-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 18px;
      }
      .bms-grid-title {
        font-size: 18px;
        font-weight: 700;
        color: #f8fafc;
      }
      .bms-grid-count {
        font-size: 13px;
        color: #64748b;
      }
      .bms-venue-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
        gap: 20px;
      }
      .bms-card {
        background: #151c2c;
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 14px;
        overflow: hidden;
        transition: transform 0.2s, box-shadow 0.2s;
        display: flex;
        flex-direction: column;
      }
      .bms-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 12px 24px rgba(0, 0, 0, 0.4);
        border-color: rgba(56, 189, 248, 0.3);
      }
      .bms-card-img-wrapper {
        position: relative;
        height: 180px;
        background: #0f172a;
      }
      .bms-card-img {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
      .bms-card-badge {
        position: absolute;
        top: 12px;
        left: 12px;
        padding: 4px 10px;
        border-radius: 6px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.3px;
        backdrop-filter: blur(8px);
      }
      .badge-instant { background: rgba(16, 185, 129, 0.85); color: #fff; }
      .badge-royal { background: rgba(245, 158, 11, 0.9); color: #fff; }
      .badge-verified { background: rgba(59, 130, 246, 0.85); color: #fff; }
      .badge-demo { background: rgba(168, 85, 247, 0.85); color: #fff; }

      .bms-card-body {
        padding: 16px;
        flex: 1;
        display: flex;
        flex-direction: column;
      }
      .bms-card-category {
        font-size: 11px;
        text-transform: uppercase;
        font-weight: 700;
        color: #38bdf8;
        margin-bottom: 4px;
        letter-spacing: 0.5px;
      }
      .bms-card-title {
        font-size: 16px;
        font-weight: 700;
        color: #ffffff;
        margin: 0 0 6px 0;
        line-height: 1.3;
      }
      .bms-card-loc {
        font-size: 12px;
        color: #94a3b8;
        display: flex;
        align-items: center;
        gap: 4px;
        margin-bottom: 10px;
      }
      .bms-card-amenities {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        margin-bottom: 14px;
      }
      .bms-amenity-tag {
        font-size: 10.5px;
        background: #1e293b;
        color: #cbd5e1;
        padding: 3px 8px;
        border-radius: 4px;
        border: 1px solid rgba(255, 255, 255, 0.05);
      }
      .bms-card-footer {
        margin-top: auto;
        padding-top: 12px;
        border-top: 1px solid rgba(255, 255, 255, 0.06);
        display: flex;
        align-items: center;
        justify-content: space-between;
      }
      .bms-price-box {
        display: flex;
        flex-direction: column;
      }
      .bms-price-amount {
        font-size: 18px;
        font-weight: 800;
        color: #f8fafc;
      }
      .bms-price-unit {
        font-size: 11px;
        color: #94a3b8;
      }
      .bms-book-btn {
        background: linear-gradient(135deg, #2563eb, #1d4ed8);
        color: #ffffff;
        border: none;
        border-radius: 8px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.2s;
      }
      .bms-book-btn:hover {
        background: linear-gradient(135deg, #3b82f6, #2563eb);
      }

      /* Modal Styling */
      .bms-modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.75);
        backdrop-filter: blur(6px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 200;
        padding: 20px;
      }
      .bms-modal {
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 16px;
        width: 100%;
        max-width: 480px;
        overflow: hidden;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);
        animation: bmsModalPop 0.25s ease-out;
      }
      @keyframes bmsModalPop {
        from { opacity: 0; transform: scale(0.95); }
        to { opacity: 1; transform: scale(1); }
      }
      .bms-modal-header {
        padding: 16px 20px;
        background: #111827;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        display: flex;
        align-items: center;
        justify-content: space-between;
      }
      .bms-modal-title {
        font-size: 16px;
        font-weight: 700;
        color: #fff;
      }
      .bms-modal-close {
        background: transparent;
        border: none;
        color: #94a3b8;
        font-size: 20px;
        cursor: pointer;
      }
      .bms-modal-body {
        padding: 20px;
        max-height: 75vh;
        overflow-y: auto;
      }
      .bms-slot-option {
        background: #0f172a;
        border: 1px solid rgba(255, 255, 255, 0.1);
        padding: 10px 14px;
        border-radius: 8px;
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        cursor: pointer;
      }
      .bms-slot-option.selected {
        border-color: #38bdf8;
        background: rgba(56, 189, 248, 0.1);
      }
      .bms-pay-btn {
        width: 100%;
        background: linear-gradient(135deg, #10b981, #059669);
        color: #ffffff;
        border: none;
        border-radius: 10px;
        padding: 12px;
        font-size: 15px;
        font-weight: 700;
        cursor: pointer;
        margin-top: 16px;
      }
      .bms-pay-btn:hover {
        background: linear-gradient(135deg, #34d399, #10b981);
      }
      .bms-toast {
        position: fixed;
        bottom: 24px;
        right: 24px;
        background: #10b981;
        color: #ffffff;
        padding: 12px 20px;
        border-radius: 8px;
        font-weight: 600;
        font-size: 14px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.4);
        z-index: 300;
      }
    `;
    document.head.appendChild(style);
  }

  // 4. Render App Shell
  function renderApp() {
    var existingApp = document.getElementById('bookmyspace-app');
    if (existingApp) existingApp.remove();

    var appContainer = document.createElement('div');
    appContainer.id = 'bookmyspace-app';
    appContainer.className = 'flt-glass-pane'; // Triggers observer in index.html

    appContainer.innerHTML = `
      <!-- Top Navigation Bar -->
      <header class="bms-navbar">
        <div class="bms-brand" id="bms-brand-home">
          <span class="bms-brand-icon">🏟️</span>
          <div>
            <span class="bms-brand-name">BookMySpace</span>
            <span class="bms-brand-tagline">Smart Space Discovery &amp; Booking</span>
          </div>
        </div>

        <div class="bms-nav-center">
          <select id="bms-city-selector" class="bms-city-select">
            <option value="Hyderabad" selected>📍 Hyderabad</option>
            <option value="Bengaluru">📍 Bengaluru</option>
            <option value="Mumbai">📍 Mumbai</option>
            <option value="Delhi-NCR">📍 Delhi-NCR</option>
            <option value="Chennai">📍 Chennai</option>
            <option value="Pune">📍 Pune</option>
          </select>

          <div class="bms-search-box">
            <input type="text" id="bms-search-input" class="bms-search-input" placeholder="Search box cricket, function halls, hotel rooms..." />
            <button class="bms-voice-btn" id="bms-voice-trigger" title="Voice Search">🎤</button>
          </div>
        </div>

        <div class="bms-nav-right">
          <div class="bms-wallet-badge">
            <span>💳 Wallet:</span>
            <strong id="bms-wallet-val">₹${state.walletBalance}</strong>
          </div>
          <div class="bms-user-avatar" title="Account Settings">NR</div>
        </div>
      </header>

      <!-- Hero & Categories -->
      <section class="bms-hero">
        <div class="bms-hero-container">
          <h1 class="bms-hero-headline">Find &amp; Book Verified Spaces</h1>
          <p class="bms-hero-sub">Explore function halls, sports turfs, day-stay rooms, and academy classes with instant slots.</p>

          <div class="bms-categories" id="bms-category-pills">
            <button class="bms-cat-pill active" data-cat="all">✨ All Spaces</button>
            <button class="bms-cat-pill" data-cat="function_halls">🏛️ Function Halls</button>
            <button class="bms-cat-pill" data-cat="lodge_rooms">🏨 Lodge / Rooms</button>
            <button class="bms-cat-pill" data-cat="institutes_classes">📚 Institutes &amp; Classes</button>
            <button class="bms-cat-pill" data-cat="sports_turfs">⚽ Sports &amp; Turfs</button>
          </div>
        </div>
      </section>

      <!-- Main Venue Grid -->
      <main class="bms-main">
        <div class="bms-grid-header">
          <span class="bms-grid-title" id="bms-grid-title">Featured Spaces in ${state.selectedCity}</span>
          <span class="bms-grid-count" id="bms-grid-count">Showing 6 verified venues</span>
        </div>

        <div class="bms-venue-grid" id="bms-venue-container">
          <!-- Cards populated dynamically -->
        </div>
      </main>

      <!-- Modal Container -->
      <div id="bms-modal-container"></div>
    `;

    document.body.appendChild(appContainer);

    setupEventHandlers();
    renderVenueCards();
  }

  // 5. Render Venue Cards
  function renderVenueCards() {
    var container = document.getElementById('bms-venue-container');
    if (!container) return;

    var filtered = venues.filter(function(v) {
      var matchCat = state.selectedCategory === 'all' || v.category === state.selectedCategory;
      var matchQuery = !state.searchQuery ||
        v.title.toLowerCase().indexOf(state.searchQuery.toLowerCase()) !== -1 ||
        v.locality.toLowerCase().indexOf(state.searchQuery.toLowerCase()) !== -1 ||
        v.categoryLabel.toLowerCase().indexOf(state.searchQuery.toLowerCase()) !== -1;
      return matchCat && matchQuery;
    });

    var countElem = document.getElementById('bms-grid-count');
    if (countElem) {
      countElem.textContent = 'Showing ' + filtered.length + ' verified venues';
    }

    if (filtered.length === 0) {
      container.innerHTML = `
        <div style="grid-column: 1/-1; text-align: center; padding: 48px; color: #94a3b8;">
          <div style="font-size: 36px; margin-bottom: 12px;">🔍</div>
          <h3 style="color: #f1f5f9; margin-bottom: 6px;">No Spaces Found</h3>
          <p>Try searching for a different area, sport, or select 'All Spaces'.</p>
        </div>
      `;
      return;
    }

    var html = filtered.map(function(venue) {
      var badgeClass = 'badge-' + venue.badgeType;
      var amenitiesHtml = venue.amenities.map(function(a) {
        return '<span class="bms-amenity-tag">' + a + '</span>';
      }).join('');

      return `
        <div class="bms-card" data-venue-id="${venue.id}">
          <div class="bms-card-img-wrapper">
            <img src="${venue.image}" alt="${venue.title}" class="bms-card-img" loading="lazy" />
            <span class="bms-card-badge ${badgeClass}">${venue.badge}</span>
          </div>
          <div class="bms-card-body">
            <span class="bms-card-category">${venue.categoryLabel}</span>
            <h3 class="bms-card-title">${venue.title}</h3>
            <div class="bms-card-loc">
              <span>📍 ${venue.locality}</span> &bull; <span>${venue.distance}</span>
            </div>
            <div style="font-size: 12px; color: #eab308; margin-bottom: 10px;">
              ⭐ <strong>${venue.rating}</strong> <span style="color: #64748b;">(${venue.reviewsCount} reviews)</span>
            </div>
            <div class="bms-card-amenities">${amenitiesHtml}</div>
            <div class="bms-card-footer">
              <div class="bms-price-box">
                <span class="bms-price-amount">₹${venue.pricePerHour.toLocaleString()}</span>
                <span class="bms-price-unit">per ${venue.priceUnit}</span>
              </div>
              <button class="bms-book-btn" onclick="window._bmsOpenBooking('${venue.id}')">Book Now</button>
            </div>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  // 6. Interactive Booking Flow
  window._bmsOpenBooking = function(venueId) {
    var venue = venues.find(function(v) { return v.id === venueId; });
    if (!venue) return;

    var modalContainer = document.getElementById('bms-modal-container');
    var slotsHtml = venue.slots.map(function(slot, index) {
      return `
        <div class="bms-slot-option ${index === 0 ? 'selected' : ''}" onclick="window._bmsSelectSlot(this)">
          <span>⏰ ${slot}</span>
          <span style="color: #34d399; font-weight: bold;">Available</span>
        </div>
      `;
    }).join('');

    var tax = Math.round(venue.pricePerHour * 0.18);
    var total = venue.pricePerHour + tax;

    modalContainer.innerHTML = `
      <div class="bms-modal-overlay" onclick="if(event.target === this) window._bmsCloseModal()">
        <div class="bms-modal">
          <div class="bms-modal-header">
            <span class="bms-modal-title">Book Slot - ${venue.title}</span>
            <button class="bms-modal-close" onclick="window._bmsCloseModal()">&times;</button>
          </div>
          <div class="bms-modal-body">
            <div style="font-size: 13px; color: #94a3b8; margin-bottom: 14px;">
              📍 ${venue.locality} &bull; ₹${venue.pricePerHour.toLocaleString()}/${venue.priceUnit}
            </div>

            <label style="display: block; font-size: 12px; font-weight: 600; color: #cbd5e1; margin-bottom: 6px;">Select Date</label>
            <input type="date" id="bms-book-date" style="width: 100%; background: #0f172a; border: 1px solid rgba(255,255,255,0.12); color: #fff; padding: 8px 12px; border-radius: 8px; margin-bottom: 14px;" value="${new Date().toISOString().split('T')[0]}" />

            <label style="display: block; font-size: 12px; font-weight: 600; color: #cbd5e1; margin-bottom: 6px;">Available Slots</label>
            <div style="margin-bottom: 16px;">${slotsHtml}</div>

            <div style="background: #0f172a; border: 1px solid rgba(255,255,255,0.08); padding: 12px; border-radius: 8px; font-size: 13px;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                <span style="color: #94a3b8;">Slot Price:</span>
                <span>₹${venue.pricePerHour.toLocaleString()}</span>
              </div>
              <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                <span style="color: #94a3b8;">GST (18%):</span>
                <span>₹${tax.toLocaleString()}</span>
              </div>
              <div style="display: flex; justify-content: space-between; font-weight: 700; color: #38bdf8; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.08);">
                <span>Total Payable:</span>
                <span>₹${total.toLocaleString()}</span>
              </div>
            </div>

            <button class="bms-pay-btn" onclick="window._bmsConfirmPayment('${venue.id}', ${total})">
              Confirm &amp; Pay via Razorpay
            </button>
          </div>
        </div>
      </div>
    `;
  };

  window._bmsSelectSlot = function(elem) {
    var siblings = elem.parentNode.querySelectorAll('.bms-slot-option');
    siblings.forEach(function(s) { s.classList.remove('selected'); });
    elem.classList.add('selected');
  };

  window._bmsCloseModal = function() {
    var modalContainer = document.getElementById('bms-modal-container');
    if (modalContainer) modalContainer.innerHTML = '';
  };

  window._bmsConfirmPayment = function(venueId, amount) {
    var venue = venues.find(function(v) { return v.id === venueId; });
    var bookingId = 'BMS-' + Math.floor(100000 + Math.random() * 900000);

    var modalContainer = document.getElementById('bms-modal-container');
    modalContainer.innerHTML = `
      <div class="bms-modal-overlay" onclick="window._bmsCloseModal()">
        <div class="bms-modal" style="text-align: center; padding: 24px;">
          <div style="font-size: 48px; margin-bottom: 12px;">🎉</div>
          <h2 style="color: #34d399; margin: 0 0 6px 0;">Booking Confirmed!</h2>
          <p style="color: #94a3b8; font-size: 14px; margin-bottom: 16px;">
            Your space reservation has been locked in system with ID <strong>${bookingId}</strong>.
          </p>
          <div style="background: #0f172a; border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 16px; margin-bottom: 18px; text-align: left; font-size: 13px;">
            <p style="margin: 0 0 4px 0;"><strong>Venue:</strong> ${venue ? venue.title : 'BookMySpace Venue'}</p>
            <p style="margin: 0 0 4px 0;"><strong>Amount Paid:</strong> ₹${amount.toLocaleString()} (Razorpay Live)</p>
            <p style="margin: 0;"><strong>Status:</strong> <span style="color: #10b981;">Confirmed &amp; Instant Pass Issued</span></p>
          </div>
          <button class="bms-book-btn" style="width: 100%; padding: 12px;" onclick="window._bmsCloseModal()">Done</button>
        </div>
      </div>
    `;
  };

  // 7. Setup Event Listeners
  function setupEventHandlers() {
    // Category pill filtering
    var catPills = document.querySelectorAll('.bms-cat-pill');
    catPills.forEach(function(pill) {
      pill.addEventListener('click', function() {
        catPills.forEach(function(p) { p.classList.remove('active'); });
        pill.classList.add('active');
        state.selectedCategory = pill.getAttribute('data-cat');
        renderVenueCards();
      });
    });

    // Search bar filtering
    var searchInput = document.getElementById('bms-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', function(e) {
        state.searchQuery = e.target.value.trim();
        renderVenueCards();
      });
    }

    // City Selector
    var citySelect = document.getElementById('bms-city-selector');
    if (citySelect) {
      citySelect.addEventListener('change', function(e) {
        state.selectedCity = e.target.value;
        var titleElem = document.getElementById('bms-grid-title');
        if (titleElem) titleElem.textContent = 'Featured Spaces in ' + state.selectedCity;
      });
    }

    // Voice search simulation
    var voiceBtn = document.getElementById('bms-voice-trigger');
    if (voiceBtn) {
      voiceBtn.addEventListener('click', function() {
        if (searchInput) {
          searchInput.value = 'Box Cricket Gachibowli';
          state.searchQuery = 'Box Cricket Gachibowli';
          renderVenueCards();
        }
      });
    }
  }

  // 8. Bootstrap Sequence: Mount UI and Notify Readiness to index.html
  injectStyles();
  renderApp();

  // Fire readiness event and call index.html completion callback
  setTimeout(function() {
    try {
      window.dispatchEvent(new CustomEvent('flutter-first-frame'));
    } catch(e) {}

    if (typeof window._bmsOnAppReady === 'function') {
      window._bmsOnAppReady();
    }
  }, 100);

})();
