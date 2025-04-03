import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { useOffers } from '../../hooks/useOffers';
import { useAuth } from '../../contexts/AuthContext';
import { OfferSummary } from '../../components/inquiries/OfferSummary';
import { ArrowLeft, Check, X } from 'lucide-react';

export function OfferViewPage() {
  const { inquiryId } = useParams<{ inquiryId: string }>();
  const navigate = useNavigate();
  const { hasRole } = useAuth();
  const { getTraderOffer, acceptOffer, rejectOffer, requestChanges, isLoading } = useOffers();
  const [offer, setOffer] = useState(null);
  const [isAccepting, setIsAccepting] = useState(false);
  const [isRejecting, setIsRejecting] = useState(false);
  const [isRequestingChanges, setIsRequestingChanges] = useState(false);
  const [changeRequest, setChangeRequest] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, [inquiryId]);

  const loadData = async () => {
    try {
      const offerData = await getTraderOffer(inquiryId);
      if (!offerData) {
        throw new Error('No offer found');
      }
      setOffer(offerData);
    } catch (err) {
      console.error('Failed to load data:', err);
      setError(err instanceof Error ? err.message : 'Failed to load offer');
    }
  };

  const handleAccept = async () => {
    try {
      setIsAccepting(true);
      await acceptOffer(offer.id);
      navigate(`/inquiries/${inquiryId}`);
    } catch (err) {
      console.error('Failed to accept offer:', err);
      setError(err instanceof Error ? err.message : 'Failed to accept offer');
    } finally {
      setIsAccepting(false);
    }
  };

  const handleReject = async () => {
    try {
      setIsRejecting(true);
      await rejectOffer(offer.id);
      navigate(`/inquiries/${inquiryId}`);
    } catch (err) {
      console.error('Failed to reject offer:', err);
      setError(err instanceof Error ? err.message : 'Failed to reject offer');
    } finally {
      setIsRejecting(false);
    }
  };

  const handleRequestChanges = async () => {
    const message = window.prompt('Please describe the changes you would like to request:');
    if (!message) return;

    try {
      setIsRequestingChanges(true);
      await requestChanges(offer.id, message);
      navigate(`/inquiries/${inquiryId}`);
    } catch (err) {
      console.error('Failed to request changes:', err);
      setError(err instanceof Error ? err.message : 'Failed to request changes');
    } finally {
      setIsRequestingChanges(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-green-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-red-50 border-l-4 border-red-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <ArrowLeft className="h-5 w-5 text-red-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!offer) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <ArrowLeft className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                No offer found. It may have been deleted or you don't have permission to view it.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <AuthGuard>
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center mb-6">
          <button
            onClick={() => navigate(`/inquiries/${inquiryId}`)}
            className="mr-4 text-gray-600 hover:text-gray-900"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <h1 className="text-2xl font-bold text-gray-900">Offer Details</h1>
        </div>

        <OfferSummary 
          offer={offer}
          onAccept={handleAccept}
          onReject={handleReject}
          onRequestChanges={handleRequestChanges} 
          showActions={true}
        />
      </div>
    </AuthGuard>
  );
}