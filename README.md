# FPMS Libasport - Fish Product Monitoring System

A comprehensive Flutter web and mobile application for monitoring fish products with role-based access control, built with Supabase backend.

## 🐟 Features

### Phase 1: Authentication & User Management ✅
- **Role-based Authentication**: Admin, Inspector, Collector, Teller, Gate Collector
- **User Management**: Create, update, delete user accounts
- **Modern UI**: Material Design 3 with smooth animations
- **Toast Notifications**: Real-time feedback system

### Phase 2: Fish Scanning & Identification (In Progress)
- **Photo Capture**: Camera integration for fish product photos
- **AI/ML Integration**: Fish species recognition (planned)
- **QR Code Generation**: Unique identifiers for each entry
- **Product Details**: Species, size, weight, vessel information

### Phase 3: Workflow Automation (Planned)
- **Order of Payment**: Collector workflow with QR codes
- **Official Receipt**: Teller payment processing
- **Clearing Certificate**: Gate validation system
- **Document Generation**: Auto-generated forms

### Phase 4: Admin Dashboard & Reports (Planned)
- **Analytics Dashboard**: Fish type distribution, revenue tracking
- **User Activity Logs**: Comprehensive audit trail
- **Export Reports**: CSV and PDF generation
- **System Statistics**: Real-time monitoring

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Dart SDK
- Supabase account
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fpms_libasport
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**
   - Create a new Supabase project
   - Run the SQL schema from `supabase/schema.sql` in your Supabase SQL editor
   - Update `lib/env.dart` with your Supabase credentials

4. **Run the application**
   ```bash
   # For web
   flutter run -d chrome
   
   # For mobile
   flutter run
   ```

### Demo Credentials
- **Admin**: `admin@fpms.com` / `admin123`
- **Inspector**: `inspector@fpms.com` / `inspector123`
- **Collector**: `collector@fpms.com` / `collector123`
- **Teller**: `teller@fpms.com` / `teller123`
- **Gate Collector**: `gate@fpms.com` / `gate123`

## 🏗️ Architecture

### Frontend (Flutter)
- **Material Design 3**: Modern, accessible UI components
- **Role-based Routing**: Dynamic navigation based on user permissions
- **State Management**: Provider pattern for state management
- **Responsive Design**: Works on web, mobile, and desktop

### Backend (Supabase)
- **PostgreSQL Database**: Relational data with proper indexing
- **Row Level Security**: Secure data access policies
- **Real-time Subscriptions**: Live updates for collaborative features
- **File Storage**: Photo and document storage
- **Edge Functions**: Serverless backend logic

### Database Schema
```
user_profiles → vessels → fish_products → orders_of_payment → official_receipts → clearing_certificates
```

## 📱 User Roles & Permissions

### Admin
- Full system access
- User management (create, update, delete)
- View all reports and analytics
- System settings and configuration

### Inspector
- Fish product inspection
- Vessel information management
- Photo capture and species identification
- View inspection reports

### Collector
- Generate Order of Payment
- Create QR codes for products
- Payment tracking
- View collection reports

### Teller
- Issue Official Receipt
- Process payments
- Payment method management
- View payment reports

### Gate Collector
- Scan clearing certificates
- Validate entries
- Gate access control
- View validation reports

## 🎨 Design System

### Color Palette
- **Primary**: Blue (#1976D2)
- **Secondary**: Complementary colors
- **Surface**: Light backgrounds with subtle shadows
- **Error/Success**: Semantic color coding

### Typography
- **Font Family**: Google Fonts Poppins
- **Hierarchy**: Clear heading and body text styles
- **Accessibility**: High contrast ratios

### Components
- **Cards**: Elevated surfaces with rounded corners
- **Buttons**: Material Design 3 button styles
- **Forms**: Consistent input styling
- **Navigation**: Rail-based navigation for desktop

## 🔧 Development

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── env.dart                  # Environment configuration
├── models/                   # Data models
├── services/                 # Business logic
├── pages/                    # UI pages
│   ├── auth/                # Authentication
│   ├── admin/               # Admin dashboard
│   ├── inspector/           # Inspector workflow
│   ├── collector/           # Collector workflow
│   ├── teller/              # Teller workflow
│   └── gate_collector/       # Gate collector workflow
└── dashboard/               # Dashboard wrapper
```

### Key Dependencies
- `supabase_flutter`: Backend integration
- `toastification`: Notification system
- `google_fonts`: Typography
- `qr_flutter`: QR code generation
- `mobile_scanner`: Camera integration
- `fl_chart`: Data visualization

## 🚀 Deployment

### Web Deployment
1. Build for web: `flutter build web`
2. Deploy to Firebase Hosting, Netlify, or Vercel
3. Configure environment variables

### Mobile Deployment
1. Build APK: `flutter build apk`
2. Build iOS: `flutter build ios`
3. Deploy to app stores

## 📊 Future Enhancements

### Phase 5: Advanced Features
- **AI Fish Recognition**: TensorFlow Lite integration
- **Offline Support**: Local data synchronization
- **Push Notifications**: Real-time alerts
- **Multi-language Support**: Internationalization
- **Advanced Analytics**: Machine learning insights

### Integration Possibilities
- **Payment Gateways**: Stripe, PayPal integration
- **Government APIs**: Port authority systems
- **IoT Sensors**: Temperature and quality monitoring
- **Blockchain**: Immutable audit trail

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

---

**Built with ❤️ for sustainable fish product monitoring**