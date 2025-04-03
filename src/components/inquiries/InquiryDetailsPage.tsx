@@ .. @@
   const { id } = useParams<{ id: string }>();
   const navigate = useNavigate();
   const { getInquiry, canEdit, isLoading: inquiryLoading } = useInquiries();
-  const { getOffersForInquiry, isLoading: offersLoading } = useOffers();
+  const { getOffersForInquiry, sendOffer, isLoading: offersLoading } = useOffers();
   const [inquiry, setInquiry] = useState(null);
   const [offers, setOffers] = useState([]);
   const [isEditing, setIsEditing] = useState(false);
   const [error, setError] = useState<Error | null>(null);
+  const [isSending, setIsSending] = useState(false);
 
   useEffect(() => {
     if (id) {
       loadInquiry(id);
       loadOffers(id);
     }
   }, [id]);
 
+  const handleSendOffer = async (offerId: string) => {
+    try {
+      setIsSending(true);
+      await sendOffer(offerId);
+      await loadOffers(id);
+      await loadInquiry(id);
+    } catch (err) {
+      console.error('Failed to send offer:', err);
+    } finally {
+      setIsSending(false);
+    }
+  };
+
   const loadInquiry = async (inquiryId: string) => {
     try {
       const data = await getInquiry(inquiryId);
       setInquiry(data);
     } catch (err) {
       console.error('Failed to load inquiry:', err);
     }
   };
@@ .. @@
               {offers.map((offer) => (
                 <div key={offer.id} className="relative">
                   {/* Edit button for draft or sent offers */}
-                  {['draft', 'sent'].includes(offer.status) && (
+                  {offer.status === 'draft' && (
                     <div className="absolute top-4 right-4 z-10">
-                      <button
-                        onClick={() => navigate(`/admin/inquiries/${inquiry.id}/offer/${offer.id}/edit`)}
-                        className="inline-flex items-center px-3 py-1.5 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
-                      >
-                        <Edit className="h-4 w-4 mr-2" />
-                        Edit Offer
-                      </button>
+                      <div className="flex space-x-2">
+                        <button
+                          onClick={() => navigate(`/admin/inquiries/${inquiry.id}/offer/${offer.id}/edit`)}
+                          className="inline-flex items-center px-3 py-1.5 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
+                        >
+                          <Edit className="h-4 w-4 mr-2" />
+                          Edit
+                        </button>
+                        <button
+                          onClick={() => handleSendOffer(offer.id)}
+                          disabled={isSending}
+                          className="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
+                        >
+                          {isSending ? (
+                            <div className="flex items-center">
+                              <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-white mr-2"></div>
+                              Sending...
+                            </div>
+                          ) : (
+                            <>Send Offer</>
+                          )}
+                        </button>
+                      </div>
                     </div>
                   )}
                   <OfferSummary 
                     offer={offer}
                     showActions={false}
                   />
                 </div>
               ))}