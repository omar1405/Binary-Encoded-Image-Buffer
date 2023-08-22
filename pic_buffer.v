//reference from here:
//link: https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/shift-register-with-evenly-spaced-taps.html
`timescale 1ns/1ps
module pic_buffer #(
    parameter DSIZE = 8,
    parameter IMAGE_WIDTH = 256,
    parameter IMAGE_LENGTH= 256,
    parameter BUFFER_SIZE = IMAGE_WIDTH*2+3
) (
	input               clk, 
    input               rst_n,
    //image buffreing control
    input               frame_start,
    input               shift,
    output reg          active_output_frame,
    //pixel input
	input  [DSIZE-1:0]  sr_in,
    // input               sr_in_valid,
    //kernel output
    output              sr_pixel_valid,
    output [DSIZE-1:0]  sr_pixel_0, sr_pixel_1, sr_pixel_2,
    output [DSIZE-1:0]  sr_pixel_3, sr_pixel_4, sr_pixel_5,
    output [DSIZE-1:0]  sr_pixel_6, sr_pixel_7, sr_pixel_8,
	output [DSIZE-1:0] sr_out
);

//image
localparam IMAGE_SIZE       = IMAGE_WIDTH*IMAGE_LENGTH;
localparam ISIZE            = $clog2(IMAGE_SIZE+1);
//buffer
localparam BUFFER_OFFSET    = BUFFER_SIZE-1;
localparam WIDTH_OFFSET     = IMAGE_WIDTH;
localparam WSIZE            = $clog2(WIDTH_OFFSET+1);
localparam CSIZE            = $clog2(BUFFER_OFFSET);

//Registers
reg [DSIZE-1:0] sr [BUFFER_SIZE-1:0];
reg 			sr_valid;
//reg [CSIZE-1:0] offset_counter;
reg active_frame;
reg [ISIZE-1:0] image_counter;
reg [WSIZE-1:0] column_counter;

//counter for the whole 
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        image_counter   <=  'd0;
        column_counter  <=  'd0;
        active_frame    <= 1'b0;
        sr_valid        <= 1'b0;
        active_output_frame <= 1'b0;

    end else if (frame_start) begin
        image_counter   <=  'd0;
        column_counter  <=  'd0;
        active_frame    <= 1'b1;
        sr_valid        <= 1'b0;
        active_output_frame <= 1'b0;

    end else if ((active_frame && shift) && (image_counter <  BUFFER_OFFSET)) begin
        image_counter <= image_counter + 'd1;
        active_frame  <= 1'b1;
        sr_valid <= 1'b0;
        active_output_frame <= 1'b0;
        if ( column_counter == WIDTH_OFFSET) begin
            column_counter <= 'd1;
        end else begin
            column_counter<= column_counter+ 1;
        end

    end else if ((active_frame && shift) && (image_counter >= BUFFER_OFFSET) && (image_counter != IMAGE_SIZE)) begin
        active_output_frame <= 1'b1;
        image_counter <= image_counter + 1;
        //column counter setup
        if ( column_counter == WIDTH_OFFSET) begin
            column_counter <= 'd1;
        end else begin
            column_counter <= column_counter+ 1;
        end
        //shift reg validity setup
        if ( column_counter == WIDTH_OFFSET || column_counter == 'd1) begin
        // if ( column_counter == WIDTH_OFFSET) begin
            sr_valid <= 1'b0;
        end else begin
            sr_valid <= 1'b1;
        end

    end else if ((active_frame && shift) && (image_counter == IMAGE_SIZE)) begin
        active_output_frame <= 1'b0;
        image_counter <=  'd0;
        sr_valid <= 1'b0;
        active_frame <= 1'b0;
    end
end

//counter until the first valid kernel output
// always @(posedge clk, negedge rst_n) begin
//     if (!rst_n) begin
//         offset_counter <= 'd0;
//         sr_valid <= 1'b0;
//     end else begin
//         if (shift) begin
//             if (offset_counter == BUFFER_OFFSET) begin
//                 sr_valid <= sr_in_valid;
//                 offset_counter <= offset_counter;    
//             end else begin
//                 sr_valid <= 1'b0;
//                 offset_counter <= offset_counter + 1'b1;
//             end
//         end else begin
//             offset_counter <= offset_counter;
//             sr_valid <= sr_in_valid;
//         end
//     end
// end

//shift register
integer n;
always @ (posedge clk)
    begin
//    if (shift == 1'b1)
//        begin
        for (n = BUFFER_SIZE-1; n>0; n = n-1) begin
            sr[n] <= sr[n-1];
        end
        if (shift == 1'b1) begin
            sr[0] <= sr_in;
        end else begin
            sr[0] <= 'd0;
        end
    end
// end
assign sr_pixel_valid = sr_valid;
assign sr_pixel_0 = sr[IMAGE_WIDTH * 2 + 2];
assign sr_pixel_1 = sr[IMAGE_WIDTH * 2 + 1];
assign sr_pixel_2 = sr[IMAGE_WIDTH * 2 + 0];
assign sr_pixel_3 = sr[IMAGE_WIDTH * 1 + 2];
assign sr_pixel_4 = sr[IMAGE_WIDTH * 1 + 1];
assign sr_pixel_5 = sr[IMAGE_WIDTH * 1 + 0];
assign sr_pixel_6 = sr[IMAGE_WIDTH * 0 + 2];
assign sr_pixel_7 = sr[IMAGE_WIDTH * 0 + 1];
assign sr_pixel_8 = sr[IMAGE_WIDTH * 0 + 0];
assign sr_out     = sr[BUFFER_SIZE-1];//this register is the pixel outside in the kernel, in the third row.
endmodule
/*
pic_buffer#(
    .DSIZE      ( 8 ),
    .IMAGE_WIDTH ( 256 ),
    .BUFFER_SIZE ( IMAGE_WIDTH*2+3 )
)u_pic_buffer(
    .clk        ( clk        ),
    .shift      ( shift      ),
    .sr_in      ( sr_in      ),
    .sr_valid   ( sr_valid   ),
    .sr_pixel_0 ( sr_pixel_0 ),
    .sr_pixel_1 ( sr_pixel_1 ),
    .sr_pixel_2 ( sr_pixel_2 ),
    .sr_pixel_3 ( sr_pixel_3 ),
    .sr_pixel_4 ( sr_pixel_4 ),
    .sr_pixel_5 ( sr_pixel_5 ),
    .sr_pixel_6 ( sr_pixel_6 ),
    .sr_pixel_7 ( sr_pixel_7 ),
    .sr_pixel_8 ( sr_pixel_8 ),
    .sr_out     ( sr_out     )
);
*/