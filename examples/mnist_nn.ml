open Core_kernel.Std
module H = Helper

let rnd ~shape =
  Ops.randomStandardNormal (Ops_m.const_int ~type_:Int32 shape) ~type_:Float
  |> Ops.mul (Ops_m.f 0.1)

let image_dim = 28 * 28
let label_count = 10
let hidden_nodes = 64
let epochs = 10000

let () =
  let train_images = Mnist.read_images "train-images-idx3-ubyte" in
  let train_labels = Mnist.read_images "train-labels-idx1-ubyte" in
  let xs = Ops_m.placeholder [ -1; image_dim ] ~type_:Float in
  let ys = Ops_m.placeholder [ -1; label_count ] ~type_:Float in
  let w1 = Ops_m.varf [ image_dim; hidden_nodes ] in
  let b1 = Ops_m.varf [ hidden_nodes ] in
  let w2 = Ops_m.varf [ hidden_nodes; label_count ] in
  let b2 = Ops_m.varf [ label_count ] in
  let w1_assign = Ops.assign w1 (rnd ~shape:[ image_dim; hidden_nodes ]) in
  let b1_assign = Ops.assign b1 (Ops_m.f ~shape:[ hidden_nodes ] 0.) in
  let w2_assign = Ops.assign w2 (rnd ~shape:[ hidden_nodes; label_count ]) in
  let b2_assign = Ops.assign b2 (Ops_m.f ~shape:[ label_count ] 0.) in
  let ys_ = Ops_m.(Ops.sigmoid (xs *^ w1 + b1) *^ w2 + b2) |> Ops.softmax in
  let cross_entropy = Ops.neg Ops_m.(reduce_mean (ys * Ops.log ys_)) in
  let gd =
    Optimizers.gradient_descent_minimizer ~alpha:0.05 ~varsf:[ w1; w2; b1; b2 ]
      cross_entropy
  in
  let session =
    H.create_session (Node.[ P cross_entropy; P w1_assign; P b1_assign; P w2_assign; P b2_assign ] @ gd)
  in
  let _output =
    H.run session
      ~outputs:[]
      ~targets:[ w1_assign; b1_assign; w2_assign; b2_assign ] 
  in
  let results = ref [] in
  let print_err n =
    let output =
      ignore (train_images, train_labels);
      H.run session
        ~inputs:[] (* TODO use train_images/train_labels *)
        ~outputs:[ cross_entropy; ys_ ]
        ~targets:[ cross_entropy ]
    in
    match output with
    | [ cross_entropy; ys_ ] ->
      H.print_tensors [ cross_entropy ] ~names:[ sprintf "ce %d" n ];
      results := (n, Tensor.to_float_list ys_) :: !results
    | _ -> assert false
  in
  for i = 0 to epochs do
    let output =
      Wrapper.Session.run session
        ~targets:(List.map gd ~f:(fun n -> Node.packed_name n |> Node.Name.to_string))
    in
    ignore output;
    if i % (epochs / 5) = 0 then print_err i
  done;
  ignore !results
