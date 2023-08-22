//reference from here:
//link: https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/shift-register-with-evenly-spaced-taps.html
`timescale 1ns/1ps
module pic_buffer_v2 #(
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
    //frame
//    output reg          active_frame_start,
//    output reg          active_frame_end,
    //pixel input
	input  [DSIZE-1:0]  sr_in,
    // input               sr_in_valid,
    //output to the rng
    output rng_flag,
    //kernel output
    output              sr_pixel_valid,
    output [DSIZE-1:0]  sr_pixel_0, sr_pixel_1, sr_pixel_2,
    output [DSIZE-1:0]  sr_pixel_3, sr_pixel_4, sr_pixel_5,
    output [DSIZE-1:0]  sr_pixel_6, sr_pixel_7, sr_pixel_8//,
	// output [DSIZE-1:0] sr_out
);

//image
localparam IMAGE_SIZE           = IMAGE_WIDTH*IMAGE_LENGTH;
localparam ISIZE                = $clog2(IMAGE_SIZE+1);
//buffer
localparam STARTING_OFFSET      = IMAGE_WIDTH+1;
localparam BUFFER_TOP_OFFSET    = IMAGE_WIDTH+2-1;
localparam BUFFER_BOT_OFFSET    = IMAGE_SIZE-IMAGE_WIDTH-1;
localparam WSIZE                = $clog2(IMAGE_WIDTH+1);
localparam CSIZE                = $clog2(STARTING_OFFSET);

//postional tags
localparam TOP_LIMIT = 2*IMAGE_WIDTH-1;
localparam BOT_LIMIT = IMAGE_SIZE-IMAGE_WIDTH-1;

//Registers
reg [DSIZE-1:0] sr [BUFFER_SIZE-1:0];
reg 			sr_valid;
//reg active_in_frame;
reg [ISIZE-1:0] image_counter;
reg [WSIZE-1:0] column_counter;
reg [CSIZE-1:0] offset_counter;
//positional flags
wire bottom_shift;
wire init_tag,t_tag,rm_tag,b_tag,r_tag,cm_tag,l_tag;
reg activate_rng;
assign rng_flag = activate_rng;
//logic for the RNGs
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        activate_rng    <= 1'b0;
    end else begin
        if (offset_counter == IMAGE_WIDTH || offset_counter == IMAGE_WIDTH + 1) begin
            activate_rng <= 1'b1;
        end else if (!shift) begin
            activate_rng <= 1'b0;
        end
    end
end

////counter for the whole 
//always @(posedge clk) begin
//    //frame start
//    if (shift && offset_counter == STARTING_OFFSET && image_counter == 'd0) begin
//        active_frame_start <= 1'b1;
//    end else begin
//        active_frame_start <= 1'b0;
//    end
//    //frame end
//    if (image_counter == IMAGE_SIZE) begin
//        active_frame_end <= 1'b1;
//    end else begin
//        active_frame_end <= 1'b0;
//    end
//end

always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        image_counter   <=  'd0;
        column_counter  <=  'd0;
//        active_in_frame    <= 1'b0;
        offset_counter <='d0;
        sr_valid        <= 1'b0;
        // active_output_frame <= 1'b0;

    end else if (frame_start) begin
        image_counter       <=  'd0;
        offset_counter      <=  'd0;
        column_counter      <=  'd0;
        // active_in_frame     <= 1'b1;
        sr_valid            <= 1'b0;
        // active_output_frame <= 1'b0;
    //not active yer
    end else if ((shift) && (offset_counter <  STARTING_OFFSET)) begin
        // active_output_frame <= 1'b0;
        // active_in_frame     <= 1'b1;
        sr_valid            <= 1'b0;
        image_counter       <=  'd0;
        column_counter      <=  'd0;
        if (offset_counter == STARTING_OFFSET-1) begin
            offset_counter  <= STARTING_OFFSET;
        end else begin
            offset_counter  <= offset_counter + 'd1;
        end

    end else if (((shift || bottom_shift) && init_tag) && (image_counter != IMAGE_SIZE)) begin
        sr_valid <= 1'b1;
        // active_output_frame <= 1'b1;
        image_counter <= image_counter + 1;
        //column counter setup
        if ( column_counter == IMAGE_WIDTH) begin
            column_counter <= 'd1;
        end else begin
            column_counter <= column_counter+ 1;
        end

    end else if ((image_counter == IMAGE_SIZE)) begin
        sr_valid <= 1'b0;
        // active_in_frame <= 1'b0;
        image_counter <=  'd0;
        // active_output_frame <= 1'b0;
    end
end

//shift register
integer n;
always @ (posedge clk)begin
    for (n = BUFFER_SIZE-1; n>0; n = n-1) begin
        sr[n] <= sr[n-1];
    end
    if (shift == 1'b1) begin
        sr[0] <= sr_in;
    end else begin
        sr[0] <= 'd0;
    end
end

//Central Pixel Postion
assign sr_pixel_valid = sr_valid;
assign bottom_shift = sr_valid && image_counter >= IMAGE_SIZE - IMAGE_WIDTH - 1 && image_counter  <= IMAGE_SIZE;
assign init_tag = offset_counter == STARTING_OFFSET;

assign l_tag    = sr_valid && column_counter == 'd1;
assign r_tag    = sr_valid && column_counter == IMAGE_WIDTH;
assign t_tag    = sr_valid && image_counter  <= 0+IMAGE_WIDTH;
assign b_tag    = sr_valid && image_counter  >= IMAGE_SIZE - IMAGE_WIDTH + 1 && image_counter  <= IMAGE_SIZE;
assign cm_tag   = sr_valid && !(r_tag || l_tag);
assign rm_tag   = sr_valid && !(t_tag || b_tag);

//pixel 0
assign sr_pixel_0 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 2]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 2]):
                    (sr[IMAGE_WIDTH * 2 + 1])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 2]):
                    (sr[IMAGE_WIDTH * 2 + 1])//implied left
):('d0)
));
//pixel 1//
assign sr_pixel_1 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 1]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 1]):
                    (sr[IMAGE_WIDTH * 2 + 1])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 1]):
                    (sr[IMAGE_WIDTH * 2 + 1])//implied left
):('d0)
));
//pixel 2//
assign sr_pixel_2 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 0]):
                    (sr[IMAGE_WIDTH * 1 + 0])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 0]):
                    (sr[IMAGE_WIDTH * 2 + 0])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 2 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 2 + 0]):
                    (sr[IMAGE_WIDTH * 2 + 0])//implied left
):('d0)
));
//pixel 3//
assign sr_pixel_3 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 2]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 2]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 2]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):('d0)
));
//pixel 4//
assign sr_pixel_4 = sr[IMAGE_WIDTH * 1 + 1];//pixel 4 is never padded as it is the center.
// (t_tag)?(   
//         (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
//         (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 1]):
//                     (sr[IMAGE_WIDTH * 1 + 1])//implied left
// ):(
// (rm_tag)?(
//         (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
//         (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 1]):
//                     (sr[IMAGE_WIDTH * 1 + 1])//implied left
// ):(
// (b_tag)?(
//         (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
//         (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 1]):
//                     (sr[IMAGE_WIDTH * 1 + 1])//implied left
// ):('d0)
// ));
//pixel 5
assign sr_pixel_5 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 0]):
                    (sr[IMAGE_WIDTH * 1 + 0])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 0]):
                    (sr[IMAGE_WIDTH * 1 + 0])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 0]):
                    (sr[IMAGE_WIDTH * 1 + 0])//implied left
):('d0)
));
//pixel 6//
assign sr_pixel_6 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 2]):
                    (sr[IMAGE_WIDTH * 0 + 1])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 2]):
                    (sr[IMAGE_WIDTH * 0 + 1])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 2]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 2]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):('d0)
));
//pixel 7//
assign sr_pixel_7 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 1]):
                    (sr[IMAGE_WIDTH * 0 + 1])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 1]):
                    (sr[IMAGE_WIDTH * 0 + 1])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 1]):
                    (sr[IMAGE_WIDTH * 1 + 1])//implied left
):('d0)
));
//pixel 8//
assign sr_pixel_8 = 
(t_tag)?(   
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 0]):
                    (sr[IMAGE_WIDTH * 0 + 0])//implied left
):(
(rm_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 0 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 0 + 0]):
                    (sr[IMAGE_WIDTH * 0 + 0])//implied left
):(
(b_tag)?(
        (r_tag)?    (sr[IMAGE_WIDTH * 1 + 1]):
        (cm_tag)?   (sr[IMAGE_WIDTH * 1 + 0]):
                    (sr[IMAGE_WIDTH * 1 + 0])//implied left
):('d0)
 ));
// reflective padding
// if          ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b100_001) begin //top left
//012   =   445
//345   =   445
//678   =   778
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b100_010) begin  //top middle
//012   =   345
//345   =   345
//678   =   678
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b100_100) begin  //top right
//012   =   344
//345   =   344
//678   =   677
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b010_001) begin //mid left
//012   =   112
//345   =   445
//678   =   778
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b010_010) begin //mid mid
//012   =   012
//345   =   345
//678   =   678
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b010_100) begin //mid right
//012   =   011
//345   =   344
//678   =   677
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b001_001) begin //bot left
//012   =   112
//345   =   445
//678   =   445
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b001_010) begin //bot mid
//012   =   0123
//345   =   345
//678   =   345
// end else if ({{t_tag,rm_tag,b_tag},{r_tag,cm_tag,l_tag}} == 6'b001_100) begin //bot right
//012   =   011
//345   =   344
//678   =   344
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