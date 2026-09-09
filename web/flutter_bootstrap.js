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
    },
    {
      id: 'v_stanza_living_pg',
      title: 'Stanza Executive Co-Living & Luxury PG',
      category: 'pg_hostels',
      categoryLabel: 'Executive PG & Co-Living',
      city: 'Hyderabad',
      locality: 'Kondapur, Whitefields',
      distance: '1.5 km',
      rating: 4.8,
      reviewsCount: 168,
      pricePerHour: 4500,
      priceUnit: 'month',
      badge: '⚡ Meals & AC Included',
      badgeType: 'instant',
      image: 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=800&auto=format&fit=crop&q=80',
      amenities: ['3 Times Buffet Food', 'Gym & Gaming Zone', 'High-Speed WiFi', 'Daily Housekeeping', 'Biometric Security'],
      slots: ['Single Private Suite', 'Twin Sharing AC Room', '3-Sharing Budget Room']
    }
  ];

  // 2. Active User State
  var state = {
    activeTab: 'home', // 'home' | 'bookings' | 'profile'
    selectedCategory: 'all',
    searchQuery: '',
    selectedCity: 'Hyderabad',
    activeBookingVenue: null,
    bookingsList: [
      {
        id: 'BMS-94821',
        venueId: 'v_hitex_convention',
        venueTitle: 'Grand Palace Convention & AC Function Hall',
        categoryLabel: 'Function Hall',
        locality: 'Hitec City, Hyderabad',
        date: '2026-09-18',
        slot: 'Evening Reception (05:00 PM - 11:30 PM)',
        amount: 25000,
        status: 'CONFIRMED',
        image: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&auto=format&fit=crop&q=80',
        bookedAt: 'Sep 08, 2026'
      }
    ],
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

      /* Category Section & Quick Filters */
      .bms-cat-header-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 12px;
      }
      .bms-cat-header-title {
        font-size: 14.5px;
        font-weight: 800;
        letter-spacing: 0.2px;
        color: #f1f5f9;
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .bms-cat-reset-btn {
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.14);
        color: #94a3b8;
        padding: 4px 12px;
        border-radius: 16px;
        font-size: 11.5px;
        font-weight: 700;
        cursor: pointer;
        transition: all 0.2s ease;
      }
      .bms-cat-reset-btn:hover, .bms-cat-reset-btn.active {
        background: #2563eb;
        color: #ffffff;
        border-color: #38bdf8;
        box-shadow: 0 0 12px rgba(37, 99, 235, 0.45);
      }

      /* 3D Glass Cards Responsive Grid (Compact, sleek & attractive) */
      .bms-3d-cards-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(195px, 1fr));
        gap: 12px;
        perspective: 1000px;
        margin-bottom: 8px;
      }

      /* Base 3D Glass Card */
      .bms-3d-glass-card {
        position: relative;
        border-radius: 16px;
        padding: 12px 14px;
        min-height: 160px;
        cursor: pointer;
        transition: transform 0.22s cubic-bezier(0.25, 1, 0.5, 1), box-shadow 0.22s cubic-bezier(0.25, 1, 0.5, 1), border-color 0.2s ease;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        transform-style: preserve-3d;
        backdrop-filter: blur(14px);
        -webkit-backdrop-filter: blur(14px);
        overflow: hidden;
      }

      /* Top Specular Light Highlight */
      .bms-3d-glass-card::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 2px;
        background: linear-gradient(90deg, rgba(255,255,255,0.85) 0%, rgba(255,255,255,0.3) 50%, rgba(255,255,255,0.85) 100%);
        opacity: 0.9;
      }

      /* Ambient Radial Glow */
      .bms-3d-glass-card::after {
        content: '';
        position: absolute;
        top: -24px;
        right: -24px;
        width: 85px;
        height: 85px;
        border-radius: 50%;
        opacity: 0.22;
        transition: opacity 0.25s, transform 0.25s;
        pointer-events: none;
      }

      .bms-3d-glass-card:hover::after {
        opacity: 0.55;
        transform: scale(1.25);
      }

      /* Dynamic Theme 1: Function Halls (Royal Indigo & Violet) */
      .bms-3d-glass-card.theme-indigo {
        background: linear-gradient(145deg, rgba(30, 27, 75, 0.8) 0%, rgba(15, 23, 42, 0.92) 100%);
        border: 1.2px solid rgba(129, 140, 248, 0.35);
        box-shadow: 0 4px 16px rgba(99, 102, 241, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.08);
      }
      .bms-3d-glass-card.theme-indigo::after {
        background: radial-gradient(circle, #818cf8 0%, transparent 70%);
      }
      .bms-3d-glass-card.theme-indigo:hover, .bms-3d-glass-card.theme-indigo.active {
        border-color: #818cf8;
        box-shadow: 0 12px 26px rgba(99, 102, 241, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        transform: perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02);
      }

      /* Dynamic Theme 2: Lodge & Day Rooms (Sunset Amber & Coral) */
      .bms-3d-glass-card.theme-amber {
        background: linear-gradient(145deg, rgba(69, 26, 3, 0.8) 0%, rgba(15, 23, 42, 0.92) 100%);
        border: 1.2px solid rgba(251, 191, 36, 0.35);
        box-shadow: 0 4px 16px rgba(245, 158, 11, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.08);
      }
      .bms-3d-glass-card.theme-amber::after {
        background: radial-gradient(circle, #f59e0b 0%, transparent 70%);
      }
      .bms-3d-glass-card.theme-amber:hover, .bms-3d-glass-card.theme-amber.active {
        border-color: #f59e0b;
        box-shadow: 0 12px 26px rgba(245, 158, 11, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        transform: perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02);
      }

      /* Dynamic Theme 3: PG & Hostels (Vivid Emerald & Cyan) */
      .bms-3d-glass-card.theme-emerald {
        background: linear-gradient(145deg, rgba(6, 78, 59, 0.8) 0%, rgba(15, 23, 42, 0.92) 100%);
        border: 1.2px solid rgba(52, 211, 153, 0.35);
        box-shadow: 0 4px 16px rgba(16, 185, 129, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.08);
      }
      .bms-3d-glass-card.theme-emerald::after {
        background: radial-gradient(circle, #10b981 0%, transparent 70%);
      }
      .bms-3d-glass-card.theme-emerald:hover, .bms-3d-glass-card.theme-emerald.active {
        border-color: #34d399;
        box-shadow: 0 12px 26px rgba(16, 185, 129, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        transform: perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02);
      }

      /* Dynamic Theme 4: Institutes & Classes (Sky Blue & Cobalt) */
      .bms-3d-glass-card.theme-sky {
        background: linear-gradient(145deg, rgba(12, 74, 110, 0.8) 0%, rgba(15, 23, 42, 0.92) 100%);
        border: 1.2px solid rgba(56, 189, 248, 0.35);
        box-shadow: 0 4px 16px rgba(14, 165, 233, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.08);
      }
      .bms-3d-glass-card.theme-sky::after {
        background: radial-gradient(circle, #38bdf8 0%, transparent 70%);
      }
      .bms-3d-glass-card.theme-sky:hover, .bms-3d-glass-card.theme-sky.active {
        border-color: #38bdf8;
        box-shadow: 0 12px 26px rgba(14, 165, 233, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        transform: perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02);
      }

      /* Dynamic Theme 5: Sports & Turfs (Neon Lime & Spring Green) */
      .bms-3d-glass-card.theme-lime {
        background: linear-gradient(145deg, rgba(54, 83, 20, 0.8) 0%, rgba(15, 23, 42, 0.92) 100%);
        border: 1.2px solid rgba(163, 230, 53, 0.35);
        box-shadow: 0 4px 16px rgba(132, 204, 22, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.08);
      }
      .bms-3d-glass-card.theme-lime::after {
        background: radial-gradient(circle, #a3e635 0%, transparent 70%);
      }
      .bms-3d-glass-card.theme-lime:hover, .bms-3d-glass-card.theme-lime.active {
        border-color: #a3e635;
        box-shadow: 0 12px 26px rgba(132, 204, 22, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.2);
        transform: perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02);
      }

      /* Card Top Elements */
      .bms-3d-card-top {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 6px;
      }
      .bms-3d-icon-orb {
        position: relative;
        width: 36px;
        height: 36px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 17px;
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.35);
        border: 1.2px solid rgba(255, 255, 255, 0.35);
      }
      .bms-3d-live-dot {
        position: absolute;
        bottom: -1px;
        right: -1px;
        width: 8.5px;
        height: 8.5px;
        border-radius: 50%;
        background: #10b981;
        border: 1.5px solid #0f172a;
        box-shadow: 0 0 6px #10b981;
      }
      .bms-3d-count-badge {
        font-size: 10px;
        font-weight: 700;
        padding: 3px 8px;
        border-radius: 12px;
        letter-spacing: 0.2px;
        backdrop-filter: blur(8px);
      }

      /* Card Mid Text */
      .bms-3d-card-mid {
        margin-bottom: 6px;
      }
      .bms-3d-card-title {
        font-size: 14px;
        font-weight: 800;
        color: #ffffff;
        margin: 0 0 2px 0;
        line-height: 1.2;
        letter-spacing: -0.2px;
      }
      .bms-3d-card-starts {
        font-size: 11.5px;
        font-weight: 700;
        letter-spacing: -0.1px;
      }

      /* Sub-pills row */
      .bms-3d-card-pills {
        display: flex;
        gap: 5px;
        margin-bottom: 8px;
      }
      .bms-3d-sub-chip {
        font-size: 9px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.1);
        color: #cbd5e1;
        padding: 2px 6px;
        border-radius: 6px;
        white-space: nowrap;
        font-weight: 600;
      }

      /* Explore Pill Button */
      .bms-3d-card-cta {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 5px 9px;
        border-radius: 7px;
        background: rgba(255, 255, 255, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.15);
        font-size: 11px;
        font-weight: 700;
        color: #ffffff;
        transition: all 0.2s ease;
      }
      .bms-3d-glass-card:hover .bms-3d-card-cta, .bms-3d-glass-card.active .bms-3d-card-cta {
        background: #ffffff;
        color: #0f172a;
        box-shadow: 0 4px 10px rgba(255, 255, 255, 0.35);
      }
      .bms-3d-card-cta .cta-arrow {
        transition: transform 0.2s ease;
        display: inline-block;
      }
      .bms-3d-glass-card:hover .bms-3d-card-cta .cta-arrow {
        transform: translateX(3px);
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
        bottom: 84px;
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

      /* Bottom Navigation Bar ('Home', 'My Bookings', 'Profile') */
      .bms-bottom-nav {
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        height: 68px;
        background: rgba(15, 23, 42, 0.94);
        backdrop-filter: blur(18px);
        -webkit-backdrop-filter: blur(18px);
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 0 16px;
        z-index: 150;
        box-shadow: 0 -4px 30px rgba(0, 0, 0, 0.55);
      }
      .bms-bottom-nav-inner {
        max-width: 580px;
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: space-around;
      }
      .bms-bottom-nav-item {
        background: transparent;
        border: none;
        outline: none;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 6px 18px;
        border-radius: 14px;
        cursor: pointer;
        transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
        color: #94a3b8;
        min-width: 86px;
        min-height: 52px;
        position: relative;
      }
      .bms-bottom-nav-item:hover {
        color: #e2e8f0;
        background: rgba(255, 255, 255, 0.05);
      }
      .bms-bottom-nav-item.active {
        color: #38bdf8;
        background: rgba(56, 189, 248, 0.12);
      }
      .bms-nav-icon-box {
        position: relative;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        font-size: 22px;
        line-height: 1;
        margin-bottom: 3px;
        transition: transform 0.2s ease;
      }
      .bms-bottom-nav-item.active .bms-nav-icon-box {
        transform: translateY(-2px) scale(1.1);
      }
      .bms-nav-badge {
        position: absolute;
        top: -4px;
        right: -10px;
        background: #ef4444;
        color: #ffffff;
        font-size: 10px;
        font-weight: 800;
        line-height: 1;
        padding: 2px 5px;
        border-radius: 10px;
        box-shadow: 0 2px 6px rgba(239, 68, 68, 0.5);
      }
      .bms-nav-label {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.2px;
      }
      .bms-bottom-nav-item.active .bms-nav-label {
        color: #38bdf8;
        font-weight: 800;
      }
      .bms-tab-view {
        width: 100%;
        padding-bottom: 96px;
      }
      .bms-view-container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 28px 20px;
      }
      .bms-view-header {
        margin-bottom: 24px;
      }
      .bms-view-title {
        font-size: 26px;
        font-weight: 800;
        color: #f8fafc;
        margin: 0 0 6px 0;
      }
      .bms-view-sub {
        font-size: 14px;
        color: #94a3b8;
        margin: 0;
      }
      .bms-booking-card {
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 16px;
        overflow: hidden;
        margin-bottom: 18px;
        display: flex;
        flex-direction: column;
        transition: transform 0.2s, box-shadow 0.2s;
      }
      @media (min-width: 768px) {
        .bms-booking-card {
          flex-direction: row;
        }
        .bms-booking-img {
          width: 240px !important;
          height: auto !important;
        }
      }
      .bms-booking-img {
        width: 100%;
        height: 180px;
        object-fit: cover;
      }
      .bms-booking-info {
        padding: 20px;
        flex: 1;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      }
      .bms-booking-badge-confirmed {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        background: rgba(16, 185, 129, 0.2);
        color: #34d399;
        font-size: 11.5px;
        font-weight: 700;
        padding: 4px 10px;
        border-radius: 6px;
        border: 1px solid rgba(16, 185, 129, 0.3);
      }
      .bms-profile-header-card {
        background: linear-gradient(135deg, rgba(30, 41, 59, 0.9), rgba(15, 23, 42, 0.95));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 20px;
        padding: 24px;
        display: flex;
        align-items: center;
        gap: 20px;
        margin-bottom: 24px;
      }
      .bms-profile-avatar-lg {
        width: 68px;
        height: 68px;
        border-radius: 50%;
        background: linear-gradient(135deg, #0284c7, #4f46e5);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24px;
        font-weight: 800;
        color: #fff;
        box-shadow: 0 4px 15px rgba(2, 132, 199, 0.4);
      }
      .bms-profile-section {
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 16px;
        overflow: hidden;
        margin-bottom: 20px;
      }
      .bms-profile-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16px 20px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        cursor: pointer;
        transition: background 0.15s;
      }
      .bms-profile-row:last-child {
        border-bottom: none;
      }
      .bms-profile-row:hover {
        background: rgba(255, 255, 255, 0.03);
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
          <div class="bms-user-avatar" id="bms-header-avatar" title="Account Settings" style="cursor: pointer;">NR</div>
        </div>
      </header>

      <!-- TAB 1: HOME VIEW -->
      <div id="bms-view-home" class="bms-tab-view">
        <!-- Hero & 3D Glass Category Section -->
        <section class="bms-hero">
        <div class="bms-hero-container">
          <h1 class="bms-hero-headline">Find &amp; Book Verified Spaces</h1>
          <p class="bms-hero-sub">Explore function halls, sports turfs, day-stay rooms, and academy classes with instant slots.</p>

          <!-- 3D Glass Categories Header -->
          <div class="bms-cat-header-row">
            <span class="bms-cat-header-title">
              <span>✨</span>
              <span>Explore Top Categories</span>
            </span>
            <button class="bms-cat-reset-btn active" id="bms-cat-reset-all" data-cat="all">All Spaces (Reset)</button>
          </div>

          <!-- 3D Glass Cards Grid (Compact, dynamic, 3D animated) -->
          <div class="bms-3d-cards-grid" id="bms-3d-category-grid">
            
            <!-- Card 1: Function Halls -->
            <div class="bms-3d-glass-card theme-indigo" data-cat="function_halls">
              <div class="bms-3d-card-top">
                <div class="bms-3d-icon-orb" style="background: linear-gradient(135deg, #4f46e5, #9333ea);">
                  <span>🏛️</span>
                  <span class="bms-3d-live-dot"></span>
                </div>
                <span class="bms-3d-count-badge" style="background: rgba(129, 140, 248, 0.22); color: #c7d2fe;">4 in Hyderabad</span>
              </div>
              <div class="bms-3d-card-mid">
                <h3 class="bms-3d-card-title">Function Halls</h3>
                <span class="bms-3d-card-starts" style="color: #818cf8;">Starts ₹25,000/day</span>
              </div>
              <div class="bms-3d-card-pills">
                <span class="bms-3d-sub-chip">💍 Marriage</span>
                <span class="bms-3d-sub-chip">🎪 AC Banquet</span>
              </div>
              <div class="bms-3d-card-cta">
                <span>Explore</span>
                <span class="cta-arrow">&rarr;</span>
              </div>
            </div>

            <!-- Card 2: Lodge & Rooms -->
            <div class="bms-3d-glass-card theme-amber" data-cat="lodge_rooms">
              <div class="bms-3d-card-top">
                <div class="bms-3d-icon-orb" style="background: linear-gradient(135deg, #d97706, #ef4444);">
                  <span>🏨</span>
                  <span class="bms-3d-live-dot"></span>
                </div>
                <span class="bms-3d-count-badge" style="background: rgba(251, 191, 36, 0.22); color: #fde68a;">8 in Hyderabad</span>
              </div>
              <div class="bms-3d-card-mid">
                <h3 class="bms-3d-card-title">Lodge &amp; Rooms</h3>
                <span class="bms-3d-card-starts" style="color: #fbbf24;">Starts ₹499/hr</span>
              </div>
              <div class="bms-3d-card-pills">
                <span class="bms-3d-sub-chip">🛌 Day Pass</span>
                <span class="bms-3d-sub-chip">🌆 Suite</span>
              </div>
              <div class="bms-3d-card-cta">
                <span>Explore</span>
                <span class="cta-arrow">&rarr;</span>
              </div>
            </div>

            <!-- Card 3: PG & Hostels -->
            <div class="bms-3d-glass-card theme-emerald" data-cat="pg_hostels">
              <div class="bms-3d-card-top">
                <div class="bms-3d-icon-orb" style="background: linear-gradient(135deg, #059669, #0891b2);">
                  <span>🏡</span>
                  <span class="bms-3d-live-dot"></span>
                </div>
                <span class="bms-3d-count-badge" style="background: rgba(52, 211, 153, 0.22); color: #a7f3d0;">12 in Hyderabad</span>
              </div>
              <div class="bms-3d-card-mid">
                <h3 class="bms-3d-card-title">PG &amp; Hostels</h3>
                <span class="bms-3d-card-starts" style="color: #34d399;">Starts ₹4,500/mo</span>
              </div>
              <div class="bms-3d-card-pills">
                <span class="bms-3d-sub-chip">🛏️ 2-Sharing</span>
                <span class="bms-3d-sub-chip">🍽️ Food Inc.</span>
              </div>
              <div class="bms-3d-card-cta">
                <span>Explore</span>
                <span class="cta-arrow">&rarr;</span>
              </div>
            </div>

            <!-- Card 4: Institutes & Classes -->
            <div class="bms-3d-glass-card theme-sky" data-cat="institutes_classes">
              <div class="bms-3d-card-top">
                <div class="bms-3d-icon-orb" style="background: linear-gradient(135deg, #0284c7, #2563eb);">
                  <span>📚</span>
                  <span class="bms-3d-live-dot"></span>
                </div>
                <span class="bms-3d-count-badge" style="background: rgba(56, 189, 248, 0.22); color: #bae6fd;">6 in Hyderabad</span>
              </div>
              <div class="bms-3d-card-mid">
                <h3 class="bms-3d-card-title">Institutes &amp; Classes</h3>
                <span class="bms-3d-card-starts" style="color: #38bdf8;">Starts ₹299/hr</span>
              </div>
              <div class="bms-3d-card-pills">
                <span class="bms-3d-sub-chip">💻 IT Lab</span>
                <span class="bms-3d-sub-chip">💃 Dance Studio</span>
              </div>
              <div class="bms-3d-card-cta">
                <span>Explore</span>
                <span class="cta-arrow">&rarr;</span>
              </div>
            </div>

            <!-- Card 5: Sports & Turfs -->
            <div class="bms-3d-glass-card theme-lime" data-cat="sports_turfs">
              <div class="bms-3d-card-top">
                <div class="bms-3d-icon-orb" style="background: linear-gradient(135deg, #65a30d, #059669);">
                  <span>⚽</span>
                  <span class="bms-3d-live-dot"></span>
                </div>
                <span class="bms-3d-count-badge" style="background: rgba(163, 230, 53, 0.22); color: #d9f99d;">14 in Hyderabad</span>
              </div>
              <div class="bms-3d-card-mid">
                <h3 class="bms-3d-card-title">Sports &amp; Turfs</h3>
                <span class="bms-3d-card-starts" style="color: #a3e635;">Starts ₹400/hr</span>
              </div>
              <div class="bms-3d-card-pills">
                <span class="bms-3d-sub-chip">🏏 Box Cricket</span>
                <span class="bms-3d-sub-chip">🏸 Badminton</span>
              </div>
              <div class="bms-3d-card-cta">
                <span>Explore</span>
                <span class="cta-arrow">&rarr;</span>
              </div>
            </div>

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
      </div> <!-- End TAB 1: HOME VIEW -->

      <!-- TAB 2: MY BOOKINGS VIEW -->
      <div id="bms-view-bookings" class="bms-tab-view" style="display: none;">
        <div class="bms-view-container">
          <div class="bms-view-header">
            <h1 class="bms-view-title">My Bookings &amp; Passes 🎟️</h1>
            <p class="bms-view-sub">Manage your space reservations, verified entry tickets, and live payment receipts</p>
          </div>
          <div id="bms-bookings-list-container">
            <!-- Dynamically populated -->
          </div>
        </div>
      </div>

      <!-- TAB 3: PROFILE VIEW -->
      <div id="bms-view-profile" class="bms-tab-view" style="display: none;">
        <div class="bms-view-container" style="max-width: 800px;">
          <div class="bms-profile-header-card">
            <div class="bms-profile-avatar-lg">NQ</div>
            <div style="flex: 1;">
              <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 4px; flex-wrap: wrap;">
                <h2 style="margin: 0; font-size: 22px; font-weight: 800; color: #fff;">Naren Q.</h2>
                <span class="bms-booking-badge-confirmed" style="background: rgba(56, 189, 248, 0.2); color: #38bdf8; border-color: rgba(56, 189, 248, 0.4);">
                  ⭐ Prime Verified Member
                </span>
              </div>
              <p style="margin: 0 0 8px 0; color: #94a3b8; font-size: 14px;">narenqe2@gmail.com • +91 98765 43210</p>
              <div style="display: flex; gap: 16px; font-size: 13px; color: #cbd5e1; flex-wrap: wrap;">
                <span>💳 Wallet: <strong style="color: #34d399;">₹${state.walletBalance}</strong></span>
                <span>🎟️ Bookings: <strong id="bms-profile-bookings-count">${state.bookingsList.length}</strong></span>
                <span>📍 Hyderabad</span>
              </div>
            </div>
          </div>

          <!-- Section: Payment & Wallet -->
          <div class="bms-profile-section">
            <div class="bms-profile-row" onclick="alert('Wallet Balance: ₹1,500. Linked via UPI & Netbanking.')">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">💳</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">Wallet &amp; Payment Methods</strong>
                  <span style="color: #94a3b8; font-size: 12px;">Manage UPI, Cards, and Auto-Refunds</span>
                </div>
              </div>
              <span style="color: #64748b;">➔</span>
            </div>
            <div class="bms-profile-row" onclick="window._bmsSwitchTab('bookings')">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">🎟️</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">Booking History &amp; Invoices</strong>
                  <span style="color: #94a3b8; font-size: 12px;">View digital entrance passes &amp; receipts</span>
                </div>
              </div>
              <span style="color: #64748b;">➔</span>
            </div>
          </div>

          <!-- Section: Preferences & Language -->
          <div class="bms-profile-section">
            <div class="bms-profile-row">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">🌐</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">App Language</strong>
                  <span style="color: #94a3b8; font-size: 12px;">Currently: English (India)</span>
                </div>
              </div>
              <select style="background: #0f172a; border: 1px solid rgba(255,255,255,0.15); color: #38bdf8; border-radius: 6px; padding: 4px 8px; font-size: 12px;">
                <option selected>English</option>
                <option>తెలుగు (Telugu)</option>
                <option>हिन्दी (Hindi)</option>
                <option>தமிழ் (Tamil)</option>
              </select>
            </div>
            <div class="bms-profile-row">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">🔔</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">Booking Reminders &amp; SMS</strong>
                  <span style="color: #94a3b8; font-size: 12px;">Instant slot confirmation &amp; pass alerts</span>
                </div>
              </div>
              <input type="checkbox" checked style="accent-color: #0284c7; width: 18px; height: 18px; cursor: pointer;" />
            </div>
          </div>

          <!-- Section: Help & Security -->
          <div class="bms-profile-section">
            <div class="bms-profile-row" onclick="alert('BookMySpace 24x7 Support: support@bookmyspace.in | Toll-free: 1800-419-SPACE')">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">🎧</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">Help &amp; Customer Support</strong>
                  <span style="color: #94a3b8; font-size: 12px;">24x7 resolution desk for court &amp; hall bookings</span>
                </div>
              </div>
              <span style="color: #64748b;">➔</span>
            </div>
            <div class="bms-profile-row" onclick="alert('Terms & Privacy: BookMySpace adheres to secure Indian data protection and encrypted payment guidelines.')">
              <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-size: 20px;">🛡️</span>
                <div>
                  <strong style="color: #fff; font-size: 14px; display: block;">Privacy &amp; Terms of Service</strong>
                  <span style="color: #94a3b8; font-size: 12px;">Data security, policies and dispute redressal</span>
                </div>
              </div>
              <span style="color: #64748b;">➔</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom Navigation Bar ('Home', 'My Bookings', 'Profile') -->
      <nav class="bms-bottom-nav" id="bms-bottom-nav" role="navigation" aria-label="Main Bottom Navigation">
        <div class="bms-bottom-nav-inner">
          <button class="bms-bottom-nav-item active" data-tab="home" id="bms-nav-home" aria-label="Home">
            <div class="bms-nav-icon-box">
              <span class="bms-nav-icon">🏠</span>
            </div>
            <span class="bms-nav-label">Home</span>
          </button>

          <button class="bms-bottom-nav-item" data-tab="bookings" id="bms-nav-bookings" aria-label="My Bookings">
            <div class="bms-nav-icon-box">
              <span class="bms-nav-icon">🎟️</span>
              <span class="bms-nav-badge" id="bms-bookings-badge">${state.bookingsList.length}</span>
            </div>
            <span class="bms-nav-label">My Bookings</span>
          </button>

          <button class="bms-bottom-nav-item" data-tab="profile" id="bms-nav-profile" aria-label="Profile">
            <div class="bms-nav-icon-box">
              <span class="bms-nav-icon">👤</span>
            </div>
            <span class="bms-nav-label">Profile</span>
          </button>
        </div>
      </nav>

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

    var newBooking = {
      id: bookingId,
      venueId: venueId,
      venueTitle: venue ? venue.title : 'BookMySpace Venue',
      categoryLabel: venue ? venue.categoryLabel : 'Space Booking',
      locality: venue ? venue.locality : (state.selectedCity + ', India'),
      date: new Date(Date.now() + 86400000 * 2).toISOString().split('T')[0],
      slot: 'Morning Session (09:00 AM - 12:00 PM)',
      amount: amount,
      status: 'CONFIRMED',
      image: venue ? venue.image : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&auto=format&fit=crop&q=80',
      bookedAt: 'Just Now'
    };
    state.bookingsList.unshift(newBooking);

    // Update badge count
    var badge = document.getElementById('bms-bookings-badge');
    if (badge) badge.textContent = state.bookingsList.length;
    var profileBadge = document.getElementById('bms-profile-bookings-count');
    if (profileBadge) profileBadge.textContent = state.bookingsList.length;

    var modalContainer = document.getElementById('bms-modal-container');
    modalContainer.innerHTML = `
      <div class="bms-modal-overlay" onclick="window._bmsCloseModal()">
        <div class="bms-modal" style="text-align: center; padding: 24px;" onclick="event.stopPropagation()">
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
          <div style="display: flex; gap: 10px;">
            <button class="bms-pay-btn" style="flex: 1; margin: 0; background: linear-gradient(135deg, #0284c7, #0369a1);" onclick="window._bmsCloseModal(); window._bmsSwitchTab('bookings');">
              View in My Bookings
            </button>
            <button class="bms-book-btn" style="flex: 1; padding: 12px; margin: 0;" onclick="window._bmsCloseModal()">Done</button>
          </div>
        </div>
      </div>
    `;
  };

  // Switch Active Tab: 'home' | 'bookings' | 'profile'
  window._bmsSwitchTab = function(tabId) {
    state.activeTab = tabId;

    var navItems = document.querySelectorAll('.bms-bottom-nav-item');
    navItems.forEach(function(item) {
      if (item.getAttribute('data-tab') === tabId) {
        item.classList.add('active');
      } else {
        item.classList.remove('active');
      }
    });

    var homeView = document.getElementById('bms-view-home');
    var bookingsView = document.getElementById('bms-view-bookings');
    var profileView = document.getElementById('bms-view-profile');

    if (homeView) homeView.style.display = (tabId === 'home') ? 'block' : 'none';
    if (bookingsView) {
      bookingsView.style.display = (tabId === 'bookings') ? 'block' : 'none';
      if (tabId === 'bookings') renderBookingsView();
    }
    if (profileView) {
      profileView.style.display = (tabId === 'profile') ? 'block' : 'none';
    }

    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Render Bookings List
  function renderBookingsView() {
    var container = document.getElementById('bms-bookings-list-container');
    if (!container) return;

    if (state.bookingsList.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 60px 20px; background: #1e293b; border-radius: 16px; border: 1px solid rgba(255,255,255,0.08);">
          <div style="font-size: 48px; margin-bottom: 14px;">🎟️</div>
          <h3 style="color: #fff; margin: 0 0 8px 0; font-size: 20px;">No Bookings Found</h3>
          <p style="color: #94a3b8; font-size: 14px; max-width: 400px; margin: 0 auto 20px auto;">
            You haven't reserved any spaces yet. Explore sports turfs, banquet halls, or hotel day-stay suites!
          </p>
          <button class="bms-book-btn" style="padding: 10px 24px;" onclick="window._bmsSwitchTab('home')">
            Browse Venues
          </button>
        </div>
      `;
      return;
    }

    var html = state.bookingsList.map(function(b) {
      return `
        <div class="bms-booking-card">
          <img src="${b.image}" alt="${b.venueTitle}" class="bms-booking-img" />
          <div class="bms-booking-info">
            <div>
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px; flex-wrap: wrap; gap: 8px;">
                <span class="bms-card-category">${b.categoryLabel}</span>
                <span class="bms-booking-badge-confirmed">✅ ${b.status}</span>
              </div>
              <h3 style="margin: 0 0 6px 0; font-size: 18px; color: #fff;">${b.venueTitle}</h3>
              <p style="margin: 0 0 12px 0; font-size: 13px; color: #94a3b8;">📍 ${b.locality}</p>
              
              <div style="background: rgba(15, 23, 42, 0.7); border: 1px solid rgba(255,255,255,0.06); border-radius: 10px; padding: 10px 14px; margin-bottom: 14px; font-size: 13px; display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 8px;">
                <div>
                  <span style="color: #64748b; font-size: 11px; display: block;">DATE</span>
                  <strong style="color: #cbd5e1;">📅 ${b.date}</strong>
                </div>
                <div>
                  <span style="color: #64748b; font-size: 11px; display: block;">TIME SLOT</span>
                  <strong style="color: #cbd5e1;">⏰ ${b.slot}</strong>
                </div>
                <div>
                  <span style="color: #64748b; font-size: 11px; display: block;">BOOKING ID</span>
                  <strong style="color: #38bdf8;">#${b.id}</strong>
                </div>
                <div>
                  <span style="color: #64748b; font-size: 11px; display: block;">AMOUNT PAID</span>
                  <strong style="color: #34d399;">₹${b.amount.toLocaleString()} (Paid)</strong>
                </div>
              </div>
            </div>

            <div style="display: flex; gap: 10px; flex-wrap: wrap;">
              <button class="bms-pay-btn" style="padding: 9px 18px; margin: 0; font-size: 13px; flex: 1; min-width: 140px; background: linear-gradient(135deg, #0284c7, #0369a1);" onclick="window._bmsShowTicket('${b.id}')">
                📱 Digital QR Pass
              </button>
              <button class="bms-slot-btn" style="padding: 9px 16px; margin: 0; font-size: 13px; flex: 1; min-width: 140px;" onclick="alert('Contacting venue manager for ${b.venueTitle}...')">
                📞 Call Venue
              </button>
            </div>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  // Show Digital Pass with QR modal
  window._bmsShowTicket = function(bookingId) {
    var b = state.bookingsList.find(function(x) { return x.id === bookingId; }) || state.bookingsList[0];
    var modalContainer = document.getElementById('bms-modal-container');
    modalContainer.innerHTML = `
      <div class="bms-modal-overlay" onclick="window._bmsCloseModal()">
        <div class="bms-modal" style="max-width: 420px; text-align: center; padding: 24px;" onclick="event.stopPropagation()">
          <div style="font-size: 14px; font-weight: 700; color: #38bdf8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px;">Verified Entry Pass</div>
          <h2 style="color: #fff; margin: 0 0 14px 0; font-size: 19px;">${b ? b.venueTitle : 'Space Reservation'}</h2>
          
          <div style="background: #ffffff; padding: 18px; border-radius: 16px; display: inline-block; margin-bottom: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);">
            <!-- High contrast mock QR Code -->
            <div style="width: 160px; height: 160px; background: #000; border: 4px solid #000; position: relative; display: flex; align-items: center; justify-content: center;">
              <div style="width: 120px; height: 120px; border: 12px solid #fff; border-radius: 4px; display: flex; align-items: center; justify-content: center; background: #000;">
                <span style="color: #fff; font-size: 26px;">🏟️</span>
              </div>
            </div>
            <div style="color: #0f172a; font-family: monospace; font-size: 13px; font-weight: 800; margin-top: 8px;">
              PASS ID: ${b ? b.id : 'BMS-84920'}
            </div>
          </div>

          <div style="background: #0f172a; border-radius: 12px; padding: 12px; font-size: 13px; text-align: left; margin-bottom: 16px;">
            <p style="margin: 0 0 4px 0; color: #94a3b8;">Slot: <strong style="color: #fff;">${b ? b.slot : 'All Day'}</strong></p>
            <p style="margin: 0 0 4px 0; color: #94a3b8;">Guest: <strong style="color: #fff;">Naren Q. (Verified Member)</strong></p>
            <p style="margin: 0; color: #10b981;">Gate Admission: <strong>Auto-Check-in Enabled</strong></p>
          </div>

          <button class="bms-book-btn" style="width: 100%; padding: 12px;" onclick="window._bmsCloseModal()">Close Pass</button>
        </div>
      </div>
    `;
  };

  // 7. Setup Event Listeners
  function setupEventHandlers() {
    // 3D Glass Category Cards Interactive Selection and 3D Tilt Animations
    var glassCards = document.querySelectorAll('.bms-3d-glass-card');
    var resetAllBtn = document.getElementById('bms-cat-reset-all');

    glassCards.forEach(function(card) {
      // 3D mouse tracking micro-interaction on desktop
      card.addEventListener('mousemove', function(e) {
        var rect = card.getBoundingClientRect();
        var x = e.clientX - rect.left;
        var y = e.clientY - rect.top;
        var centerX = rect.width / 2;
        var centerY = rect.height / 2;
        var rotateX = ((y - centerY) / centerY) * -7;
        var rotateY = ((x - centerX) / centerX) * 7;
        card.style.transform = 'perspective(1000px) rotateX(' + rotateX.toFixed(1) + 'deg) rotateY(' + rotateY.toFixed(1) + 'deg) translateY(-5px) scale(1.025)';
      });

      card.addEventListener('mouseleave', function() {
        if (card.classList.contains('active')) {
          card.style.transform = 'perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02)';
        } else {
          card.style.transform = '';
        }
      });

      // Card click filter
      card.addEventListener('click', function() {
        glassCards.forEach(function(c) {
          c.classList.remove('active');
          c.style.transform = '';
        });
        if (resetAllBtn) resetAllBtn.classList.remove('active');

        card.classList.add('active');
        card.style.transform = 'perspective(1000px) rotateX(-4deg) rotateY(3deg) translateY(-5px) scale(1.02)';

        state.selectedCategory = card.getAttribute('data-cat');
        renderVenueCards();

        // Smooth scroll to venues
        var venueGrid = document.getElementById('bms-venue-container');
        if (venueGrid) {
          venueGrid.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });
    });

    // Reset All button
    if (resetAllBtn) {
      resetAllBtn.addEventListener('click', function() {
        glassCards.forEach(function(c) {
          c.classList.remove('active');
          c.style.transform = '';
        });
        resetAllBtn.classList.add('active');
        state.selectedCategory = 'all';
        renderVenueCards();
      });
    }

    // Category pill filtering (if any)
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

    // Bottom Navigation Bar items ('Home', 'My Bookings', 'Profile')
    var navButtons = document.querySelectorAll('.bms-bottom-nav-item');
    navButtons.forEach(function(btn) {
      btn.addEventListener('click', function() {
        var targetTab = btn.getAttribute('data-tab');
        if (targetTab && window._bmsSwitchTab) {
          window._bmsSwitchTab(targetTab);
        }
      });
    });

    // Top logo click -> return to Home tab
    var brandLogo = document.getElementById('bms-brand-home');
    if (brandLogo) {
      brandLogo.addEventListener('click', function() {
        if (window._bmsSwitchTab) window._bmsSwitchTab('home');
      });
    }

    // Top header avatar click -> open Profile tab
    var headerAvatar = document.getElementById('bms-header-avatar');
    if (headerAvatar) {
      headerAvatar.addEventListener('click', function() {
        if (window._bmsSwitchTab) window._bmsSwitchTab('profile');
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
