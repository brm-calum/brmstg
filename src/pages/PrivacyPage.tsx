import React from 'react';
import { Shield } from 'lucide-react';

export function PrivacyPage() {
  return (
    <div className="py-16 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <Shield className="mx-auto h-12 w-12 text-green-600" />
          <h1 className="mt-4 text-4xl font-bold text-gray-900">
            Privacy Policy
          </h1>
          <p className="mt-4 text-xl text-gray-600">
            Last updated: March 26, 2025
          </p>
        </div>

        <div className="mt-16 prose prose-green mx-auto">
          <h2>1. Introduction</h2>
          <p>
            BRM Warehouse ("we," "our," or "us") is committed to protecting your privacy. This Privacy
            Policy explains how we collect, use, disclose, and safeguard your information when you use
            our warehouse booking platform.
          </p>

          <h2>2. Information We Collect</h2>
          <h3>2.1 Information You Provide</h3>
          <ul>
            <li>Account information (name, email, password)</li>
            <li>Profile information (company name, contact details)</li>
            <li>Booking and inquiry details</li>
            <li>Communication preferences</li>
            <li>Payment information</li>
          </ul>

          <h3>2.2 Automatically Collected Information</h3>
          <ul>
            <li>Device information (IP address, browser type)</li>
            <li>Usage data (pages visited, actions taken)</li>
            <li>Location data (when searching for warehouses)</li>
            <li>Cookies and similar technologies</li>
          </ul>

          <h2>3. How We Use Your Information</h2>
          <p>We use the collected information to:</p>
          <ul>
            <li>Process and manage warehouse bookings</li>
            <li>Facilitate communication between users</li>
            <li>Improve our services and user experience</li>
            <li>Send important notifications and updates</li>
            <li>Prevent fraud and ensure platform security</li>
            <li>Comply with legal obligations</li>
          </ul>

          <h2>4. Information Sharing</h2>
          <p>We may share your information with:</p>
          <ul>
            <li>Warehouse owners (for booking purposes)</li>
            <li>Service providers and partners</li>
            <li>Legal authorities when required by law</li>
          </ul>

          <h2>5. Data Security</h2>
          <p>
            We implement appropriate technical and organizational measures to protect your personal
            information. However, no method of transmission over the Internet is 100% secure, and we
            cannot guarantee absolute security.
          </p>

          <h2>6. Your Rights</h2>
          <p>You have the right to:</p>
          <ul>
            <li>Access your personal information</li>
            <li>Correct inaccurate data</li>
            <li>Request deletion of your data</li>
            <li>Object to processing of your data</li>
            <li>Withdraw consent</li>
          </ul>

          <h2>7. Cookies</h2>
          <p>
            We use cookies and similar tracking technologies to enhance your experience. You can
            control cookie settings through your browser preferences.
          </p>

          <h2>8. Children's Privacy</h2>
          <p>
            Our services are not intended for users under 18 years of age. We do not knowingly
            collect information from children.
          </p>

          <h2>9. Changes to Privacy Policy</h2>
          <p>
            We may update this Privacy Policy periodically. We will notify you of any material
            changes by posting the updated policy on this page.
          </p>

          <h2>10. Contact Us</h2>
          <p>
            If you have questions about this Privacy Policy, please contact us at:{' '}
            <a href="mailto:privacy@brm24.com">privacy@brm24.com</a>
          </p>

          <h2>11. Data Retention</h2>
          <p>
            We retain your personal information for as long as necessary to provide our services and
            comply with legal obligations. You can request deletion of your data at any time.
          </p>

          <h2>12. International Data Transfers</h2>
          <p>
            Your information may be transferred to and processed in countries other than your own.
            We ensure appropriate safeguards are in place for such transfers.
          </p>
        </div>
      </div>
    </div>
  );
}