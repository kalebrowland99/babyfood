/**
 * Invoice Service - Handles PDF generation and email sending
 */

const PDFDocument = require("pdfkit");
const { Resend } = require("resend");
const { getStorage } = require("firebase-admin/storage");
const { getFirestore } = require("firebase-admin/firestore");

/**
 * Generate a PDF invoice
 * @param {Object} invoice - Invoice data
 * @returns {Promise<Buffer>} - PDF buffer
 */
async function generateInvoicePDF(invoice) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ 
        size: "LETTER",
        margin: 50 
      });
      
      const buffers = [];
      doc.on("data", buffers.push.bind(buffers));
      doc.on("end", () => {
        const pdfBuffer = Buffer.concat(buffers);
        resolve(pdfBuffer);
      });
      
      // Header
      doc.fontSize(28).text("INVOICE", 50, 50);
      
      // Invoice number and date
      doc.fontSize(10).text(`#${invoice.number}`, 50, 90);
      if (invoice.issuedDate) {
        const issueDate = new Date(invoice.issuedDate);
        doc.text(`Issued ${issueDate.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}`, 50, 105);
      }
      
      // From section (Business info)
      doc.fontSize(10).text("FROM", 50, 140);
      doc.fontSize(12).text(invoice.businessName || "615films", 50, 155);
      if (invoice.businessPhone) {
        doc.fontSize(10).text(invoice.businessPhone, 50, 170);
      }
      if (invoice.businessEmail) {
        doc.fontSize(10).text(invoice.businessEmail, 50, 185);
      }
      if (invoice.businessAddress) {
        doc.fontSize(10).text(invoice.businessAddress, 50, 200);
      }
      
      // Bill To section (Client info)
      if (invoice.client) {
        doc.fontSize(10).text("BILL TO", 350, 140);
        doc.fontSize(12).text(invoice.client.name, 350, 155);
        if (invoice.client.clientId) {
          doc.fontSize(10).text(invoice.client.clientId, 350, 170);
        }
        if (invoice.client.email) {
          doc.fontSize(10).text(invoice.client.email, 350, 185);
        }
        if (invoice.client.address) {
          doc.fontSize(10).text(invoice.client.address, 350, 200);
        }
      }
      
      // Line items table
      let tableTop = 260;
      
      // Table header
      doc.fontSize(10)
         .text("Description", 50, tableTop)
         .text("QTY", 350, tableTop, { width: 50, align: "center" })
         .text("Price, USD", 420, tableTop, { width: 80, align: "right" })
         .text("Amount, USD", 510, tableTop, { width: 80, align: "right" });
      
      // Divider line
      doc.moveTo(50, tableTop + 20)
         .lineTo(550, tableTop + 20)
         .stroke();
      
      // Line items
      let currentY = tableTop + 35;
      
      if (invoice.items && invoice.items.length > 0) {
        invoice.items.forEach((item) => {
          const quantity = item.quantity || 1;
          const price = item.price || 0;
          const amount = quantity * price;
          
          doc.fontSize(10)
             .text(item.name, 50, currentY, { width: 280 })
             .text(quantity.toString(), 350, currentY, { width: 50, align: "center" })
             .text(`$${price.toFixed(2)}`, 420, currentY, { width: 80, align: "right" })
             .text(`$${amount.toFixed(2)}`, 510, currentY, { width: 80, align: "right" });
          
          currentY += 25;
        });
      }
      
      // Divider line before totals
      currentY += 10;
      doc.moveTo(50, currentY)
         .lineTo(550, currentY)
         .stroke();
      
      // Subtotal
      currentY += 20;
      doc.fontSize(10)
         .text("Subtotal", 420, currentY)
         .text(`$${(invoice.subtotal || 0).toFixed(2)}`, 510, currentY, { width: 80, align: "right" });
      
      // Discount (if any)
      if (invoice.discount && invoice.discount > 0) {
        currentY += 20;
        doc.text("Discount", 420, currentY)
           .text(`-$${invoice.discount.toFixed(2)}`, 510, currentY, { width: 80, align: "right" });
      }
      
      // Total
      currentY += 20;
      doc.fontSize(12)
         .font("Helvetica-Bold")
         .text("Total", 420, currentY)
         .text(`$${(invoice.total || 0).toFixed(2)}`, 510, currentY, { width: 80, align: "right" });
      
      // Notes section (if present)
      if (invoice.notes && invoice.notes.trim().length > 0) {
        currentY += 60;
        doc.fontSize(10)
           .font("Helvetica-Bold")
           .text("Notes", 50, currentY);
        
        currentY += 15;
        doc.fontSize(9)
           .font("Helvetica")
           .text(invoice.notes, 50, currentY, { width: 500 });
      }
      
      // Footer
      const footerY = 700;
      doc.fontSize(8)
         .fillColor("#666666")
         .text(`Inv. #${invoice.number}    1 of 1`, 50, footerY, { align: "center", width: 500 });
      
      doc.end();
      
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Generate HTML email template for invoice
 * @param {Object} invoice - Invoice data
 * @param {string} businessName - Business name
 * @returns {string} - HTML email content
 */
function generateInvoiceEmailHTML(invoice, businessName = "615films") {
  const clientName = (invoice.client && invoice.client.name) || "Customer";
  const invoiceNumber = invoice.number || "000";
  const total = (invoice.total || 0).toFixed(2);
  const issueDate = invoice.issuedDate 
    ? new Date(invoice.issuedDate).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
    : "Today";
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Invoice #${invoiceNumber}</title>
      <style>
        body { 
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
          line-height: 1.6; 
          color: #333; 
          background-color: #f5f5f5;
          margin: 0;
          padding: 0;
        }
        .container { 
          max-width: 600px; 
          margin: 40px auto; 
          background: white;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .header { 
          background: #000;
          color: white;
          padding: 30px;
          text-align: center;
        }
        .header h1 {
          margin: 0;
          font-size: 24px;
          font-weight: 600;
        }
        .content {
          padding: 40px 30px;
        }
        .greeting {
          font-size: 18px;
          margin-bottom: 20px;
        }
        .invoice-info {
          background: #f8f9fa;
          border-radius: 8px;
          padding: 20px;
          margin: 20px 0;
        }
        .invoice-info h2 {
          margin: 0 0 10px 0;
          font-size: 16px;
          color: #666;
        }
        .invoice-number {
          font-size: 24px;
          font-weight: bold;
          margin: 5px 0;
        }
        .amount {
          font-size: 36px;
          font-weight: bold;
          color: #000;
          margin: 10px 0;
        }
        .details {
          font-size: 14px;
          color: #666;
        }
        .button {
          display: inline-block;
          background: #000;
          color: white;
          padding: 14px 32px;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          margin: 20px 0;
        }
        .button:hover {
          background: #333;
        }
        .footer {
          background: #f8f9fa;
          padding: 30px;
          text-align: center;
          font-size: 14px;
          color: #666;
        }
        .footer p {
          margin: 5px 0;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>📄 ${businessName}</h1>
        </div>
        
        <div class="content">
          <p class="greeting">Hi ${clientName},</p>
          
          <p>Please find attached your latest invoice. If you have any questions, feel free to reach out.</p>
          
          <div class="invoice-info">
            <h2>Invoice Details</h2>
            <div class="invoice-number">#${invoiceNumber}</div>
            <div class="amount">$${total}</div>
            <div class="details">Issued ${issueDate}</div>
          </div>
          
          <p style="margin-top: 30px;">The full invoice is attached as a PDF to this email.</p>
          
          <p style="margin-top: 30px;">Many thanks,<br><strong>${businessName}</strong></p>
        </div>
        
        <div class="footer">
          <p>This is an automated invoice email.</p>
          <p>© ${new Date().getFullYear()} ${businessName}. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Send invoice via email using Resend
 * @param {Object} params - Parameters for sending invoice
 * @returns {Promise<Object>} - Result of send operation
 */
async function sendInvoiceEmail({ invoice, recipientEmail, senderEmail, businessName }) {
  try {
    console.log(`📧 Preparing to send invoice #${invoice.number} to ${recipientEmail}`);
    
    // Get Resend API key from environment
    const resendApiKey = process.env.RESEND_API_KEY;
    if (!resendApiKey) {
      throw new Error("RESEND_API_KEY environment variable is not set");
    }
    
    const resend = new Resend(resendApiKey);
    
    // Generate PDF
    console.log("📄 Generating PDF...");
    const pdfBuffer = await generateInvoicePDF(invoice);
    console.log(`✅ PDF generated (${pdfBuffer.length} bytes)`);
    
    // Upload PDF to Firebase Storage
    const storage = getStorage();
    const bucket = storage.bucket();
    const fileName = `invoices/${invoice.id || invoice.number}/invoice-${invoice.number}.pdf`;
    const file = bucket.file(fileName);
    
    await file.save(pdfBuffer, {
      metadata: {
        contentType: "application/pdf",
      },
    });
    console.log(`✅ PDF uploaded to Firebase Storage: ${fileName}`);
    
    // Generate email HTML
    const emailHTML = generateInvoiceEmailHTML(invoice, businessName);
    
    // Convert PDF buffer to base64 for attachment
    const pdfBase64 = pdfBuffer.toString("base64");
    
    // Send email via Resend
    console.log(`📤 Sending email via Resend...`);
    const result = await resend.emails.send({
      from: senderEmail || `${businessName} <invoices@resend.dev>`,
      to: recipientEmail,
      subject: `Invoice #${invoice.number} from ${businessName}`,
      html: emailHTML,
      attachments: [{
        filename: `invoice-${invoice.number}.pdf`,
        content: pdfBase64,
      }],
    });
    
    console.log(`✅ Invoice sent successfully via Resend:`, result);
    
    // Update invoice status in Firestore
    const db = getFirestore();
    if (invoice.id) {
      await db.collection("invoices").doc(invoice.id).update({
        status: "sent",
        sentAt: new Date(),
        sentTo: recipientEmail,
        lastModified: new Date(),
      });
      console.log(`✅ Invoice status updated in Firestore`);
    }
    
    return {
      success: true,
      messageId: result.id,
      pdfPath: fileName,
    };
    
  } catch (error) {
    console.error("❌ Error sending invoice:", error);
    throw error;
  }
}

module.exports = {
  generateInvoicePDF,
  generateInvoiceEmailHTML,
  sendInvoiceEmail,
};

